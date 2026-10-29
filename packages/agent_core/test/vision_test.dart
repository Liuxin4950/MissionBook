import 'dart:convert';
import 'dart:typed_data';

import 'package:agent_core/agent_core.dart';
import 'package:agent_core/src/models/wire_codec.dart';
import 'package:agent_core/src/sessions/message_codec.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';

import 'support/foundation_fixtures.dart';

void main() {
  final bytes = Uint8List.fromList(
    image.encodePng(image.Image(width: 32, height: 20)),
  );
  final profiles = AgentConfiguration.deepSeek();

  test('DeepSeek 使用官方完整能力，其他模型保留各自预算', () {
    for (final profile in profiles.profiles) {
      expect(profile.contextWindowTokens, 1048576);
      expect(profile.outputTokenLimit, 393216);
      expect(profile.maxOutputTokens, 8192);
    }
    expect(testProfile('other').contextWindowTokens, 24000);
    final profile = profiles.profile('deepseek-chat');
    expect(
      () => ModelProfile.fromJson({
        ...profile.toJson(),
        'maxOutputTokens': 393217,
      }),
      throwsArgumentError,
    );
    expect(
      () => ModelProfile.fromJson({
        ...profile.toJson(),
        'contextWindowTokens': 2000000,
      }),
      throwsArgumentError,
    );
    final secure = ModelProfile.fromJson({
      ...profile.toJson(),
      'credentialKey': 'keystore/deepseek.personal',
    });
    expect(secure.credentialKey, 'keystore/deepseek.personal');
    expect(
      () => ModelProfile.fromJson({
        ...profile.toJson(),
        'outputTokenLimit': 393217,
      }),
      throwsArgumentError,
    );
    final withoutLimit = ModelProfile.fromJson({
      ...profile.toJson(),
      'outputTokenLimit': null,
    });
    expect(
      () => encodeModelRequest(
        withoutLimit,
        ModelRequest(
          systemPrompt: '',
          messages: [UserMessage(text: '问题')],
          tools: [],
          maxOutputTokens: 393217,
        ),
        stream: false,
      ),
      throwsA(isA<ModelException>()),
    );
  });

  test('文件接口的无效元数据返回可识别错误', () {
    for (final size in [null, '100', -1, 65 * 1024 * 1024]) {
      expect(
        () => UploadedImage.fromJson({
          'id': 'file-invalid',
          'filename': 'a.png',
          'bytes': size,
        }),
        throwsA(
          isA<ModelException>().having(
            (e) => e.code,
            'code',
            'invalid_response',
          ),
        ),
      );
    }
  });

  test('按照真实图片格式识别而非扩展名；损坏文件不能发给模型', () {
    final input = ImageInput.fromBytes(bytes, name: 'wrong.jpg');
    expect(input.mediaType, 'image/png');
    expect(input.width, 32);
    expect(input.height, 20);
    final block = input.inline(detail: ImageDetail.low);
    expect(block.url, startsWith('data:image/png;base64,'));
    expect(block.width, 32);
    expect(block.detail, ImageDetail.low);
    expect(
      () =>
          ImageInput.fromBytes(Uint8List.fromList(utf8.encode('not an image'))),
      throwsArgumentError,
    );
    expect(() => ImageInput.fromBytes(Uint8List(0)), throwsArgumentError);
  });

  test('双协议图片与文件引用可持久化还原；Files 仅能交回所属供应商', () {
    for (final profile in profiles.profiles) {
      for (final block in [
        ImageInput.fromBytes(bytes, name: 'test.png').inline(),
        ImageBlock(url: 'https://example.invalid/a.png'),
        ImageBlock.file(id: 'file-api-example', label: 'test.png'),
      ]) {
        final original = UserMessage.withContent(
          content: [
            const TextBlock(text: '识别'),
            block,
          ],
        );
        final restored = decodeMessage(encodeMessage(original));
        final body = encodeModelRequest(
          profile,
          _request([restored]),
          stream: false,
        );
        final encoded = jsonEncode(body);
        expect(
          encoded,
          contains(
            block.fileId ??
                (block.url.startsWith('data:')
                    ? base64Encode(bytes)
                    : block.url),
          ),
        );
        expect(restored.content.last, isA<ImageBlock>());
      }
    }
    final other = testProfile('other', protocol: ModelProtocol.chatCompletions);
    expect(
      () => encodeModelRequest(
        other,
        _request([
          UserMessage.withContent(
            content: [ImageBlock.file(id: 'file-api-example')],
          ),
        ]),
        stream: false,
      ),
      throwsA(
        isA<ModelException>().having(
          (error) => error.code,
          'code',
          'foreign_file',
        ),
      ),
    );
  });

  test('图片数量、总大小和多图尺寸提前校验；纯文字模型拒绝图片', () {
    final profile = profiles.profile('deepseek-chat');
    void check(List<ImageBlock> blocks, String code) {
      expect(
        () => encodeModelRequest(
          profile,
          _request([UserMessage.withContent(content: blocks)]),
          stream: false,
        ),
        throwsA(
          isA<ModelException>().having((error) => error.code, 'code', code),
        ),
      );
    }

    check(
      List.generate(
        601,
        (_) => ImageBlock(url: 'https://example.invalid/image'),
      ),
      'too_many_images',
    );
    check(
      List.generate(
        15,
        (_) =>
            ImageBlock.file(id: 'file-api-example', width: 5000, height: 100),
      ),
      'image_dimensions',
    );
    check([
      ImageBlock.file(id: 'file-api-example', byteLength: 65 * 1024 * 1024),
    ], 'image_too_large');
    check(
      List.generate(
        4,
        (_) => ImageBlock.file(
          id: 'file-api-example',
          byteLength: 60 * 1024 * 1024,
        ),
      ),
      'images_too_large',
    );
    final textOnly = ModelProfile.fromJson({
      ...profile.toJson(),
      'supportsImages': false,
    });
    expect(
      () => encodeModelRequest(
        textOnly,
        _request([
          UserMessage.withContent(
            content: [ImageBlock(url: 'https://example.invalid/image')],
          ),
        ]),
        stream: false,
      ),
      throwsA(
        isA<ModelException>().having(
          (error) => error.code,
          'code',
          'unsupported_images',
        ),
      ),
    );
  });

  test('图片上传、检索、分页和删除使用官方协议，返回文件引用', () async {
    final methods = <String>[];
    final client = MockClient((request) async {
      methods.add(request.method);
      expect(request.headers['authorization'], 'Bearer test-key');
      if (request.method == 'POST') {
        expect(
          request.headers['content-type'],
          contains('multipart/form-data'),
        );
        expect(request.bodyBytes, containsAllInOrder(bytes));
        final form = latin1.decode(request.bodyBytes);
        expect(form, contains('user_data'));
        expect(form, isNot(contains('expires_after')));
      }
      final file = {
        'id': 'file-api-example',
        'filename': 'test.png',
        'bytes': bytes.length,
      };
      final response = request.method == 'DELETE'
          ? {'id': 'file-api-example', 'deleted': true}
          : request.url.queryParameters.containsKey('limit')
          ? {
              'data': [file],
            }
          : file;
      return http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final files = DeepSeekFilesClient(
      credentials: (_) => 'test-key',
      client: client,
    );
    addTearDown(() {
      files.close();
      client.close();
    });
    final uploaded = await files.upload(
      ImageInput.fromBytes(bytes, name: 'test.png'),
    );
    expect(uploaded.block.fileId, 'file-api-example');
    expect(uploaded.block.width, 32);
    expect((await files.retrieve(uploaded.id)).name, 'test.png');
    expect(await files.list(), hasLength(1));
    await files.delete(uploaded.id);
    expect(methods, ['POST', 'GET', 'GET', 'DELETE']);
  });

  test('Messages 文件引用附加正确 beta 头，Chat detail 与 JSON 模式正确编码', () async {
    final profile = profiles.profile('deepseek');
    final client = MockClient((request) async {
      expect(request.headers['anthropic-beta'], 'files-api-2025-04-14');
      expect(jsonDecode(request.body)['messages'][0]['content'][0]['source'], {
        'type': 'file',
        'file_id': 'file-api-example',
      });
      return http.Response(
        jsonEncode({
          'role': 'assistant',
          'type': 'message',
          'model': profile.model,
          'stop_reason': 'end_turn',
          'content': [
            {'type': 'text', 'text': '图片说明'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final model = HttpAgentModel(
      profile: ModelProfile.fromJson({
        ...profile.toJson(),
        'streamResponses': false,
      }),
      credentials: (_) => 'test-key',
      client: client,
    );
    addTearDown(() {
      model.close();
      client.close();
    });
    expect(
      (await model.complete(
        _request([
          UserMessage.withContent(
            content: [ImageBlock.file(id: 'file-api-example')],
          ),
        ]),
        CancellationToken(),
      )).message.text,
      '图片说明',
    );
    final chat = encodeModelRequest(
      profiles.profile('deepseek-chat'),
      ModelRequest(
        systemPrompt: 'output json',
        messages: [
          UserMessage.withContent(
            content: [
              ImageInput.fromBytes(bytes).inline(detail: ImageDetail.low),
            ],
          ),
        ],
        tools: [],
        jsonOutput: true,
      ),
      stream: false,
    );
    expect(chat['response_format'], {'type': 'json_object'});
    expect(
      (chat['messages'] as List).last['content'][0]['image_url']['detail'],
      'low',
    );
  });

  test('不同供应商或模型的思考不回传；DeepSeek 工具往返保留本模型思考', () {
    final profile = profiles.profile('deepseek-chat');
    Map<String, Object?> encode(String provider, String model) =>
        encodeModelRequest(
          profile,
          ModelRequest(
            systemPrompt: '',
            messages: [
              AssistantMessage(
                provider: provider,
                model: model,
                content: [
                  const ThinkingBlock(text: 'reasoning'),
                  const TextBlock(text: '回答'),
                ],
              ),
            ],
            tools: [
              readTool(
                (input, context) => const ToolOutput.success(''),
              ).definition,
            ],
          ),
          stream: false,
        );
    expect(
      jsonEncode(encode('deepseek', profile.model)),
      contains('reasoning_content'),
    );
    expect(
      jsonEncode(encode('other', profile.model)),
      isNot(contains('reasoning_content')),
    );
    expect(
      jsonEncode(encode('deepseek', 'other-model')),
      isNot(contains('reasoning_content')),
    );
  });
}

ModelRequest _request(List<AgentMessage> messages) =>
    ModelRequest(systemPrompt: '', messages: messages, tools: []);
