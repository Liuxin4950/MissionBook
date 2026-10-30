import 'package:http/http.dart' as http;

http.Client publicHttpClient() =>
    throw UnsupportedError('此浏览器无法校验目标网络地址，请在 Android 或桌面端读取网页');
