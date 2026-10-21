// material.dart 提供页面、输入框、按钮、对话框等 Material 风格组件。
import 'package:flutter/material.dart';
// services.dart 提供输入格式器，本页用它限制分钟输入框只接受数字。
import 'package:flutter/services.dart';

import '../../application/create_mission.dart';

// Widget 描述页面配置；可变化的输入与资源交给下面的 State 管理。
class CreateMissionPage extends StatefulWidget {
  // required 要求打开本页的调用者提供业务对象；this 将参数存到同名属性。
  // super.key 将组件身份标识交给父类；本页目前无需手动指定 key。
  const CreateMissionPage({super.key, required this.createMission});

  // 从 TodayPage 传来的同一个业务对象；后续保存时调用，不在本页重新创建。
  final CreateMission createMission;

  @override
  State<CreateMissionPage> createState() {
    // Flutter 将此 State 与当前页面配置关联，再调用它的 build。
    return _CreateMissionPageState();
  }
}

class _CreateMissionPageState extends State<CreateMissionPage> {
  // 控制器连接输入框，保存文字、光标等编辑状态；.text 可读取当前文字。
  // 在 State 创建时初始化，避免 build 重复执行时丢失输入。
  // final 固定控制器引用，不妨碍控制器内部的文字变化；下划线表示库内私有。
  final _titleController = TextEditingController();
  final _durationController = TextEditingController();

  // late 表示在 initState 中初始化；final 保留打开表单时的日期，供返回时比较。
  late final String _initialDateText;
  // 与其他控制器一样保存在 State 中，不随 build 重建而重置输入。
  late final TextEditingController _dateController;

  @override
  void initState() {
    super.initState();
    // 取设备当地的今天作为表单默认日期；这里尚未取得排期的 IANA 时区。
    final today = DateTime.now();
    // padLeft 向左补零，例如 3 → '03'，使日期符合 YYYY-MM-DD 格式。
    final year = today.year.toString().padLeft(4, '0');
    final month = today.month.toString().padLeft(2, '0');
    final day = today.day.toString().padLeft(2, '0');
    _initialDateText = '$year-$month-$day';
    // text 将默认日期真正填入控制器；hintText 仅是提示，不能代替实际值。
    _dateController = TextEditingController(text: _initialDateText);
  }

  @override
  void dispose() {
    // Flutter 永久移除此 State 时调用；释放控制器的监听等资源。
    // 关闭确认框不会销毁创建页，也不会执行这里。
    _titleController.dispose();
    _durationController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // 顶部返回与系统返回共用此方法。Future<void> 表示异步结束后不提供结果值。
  Future<void> _requestClose() async {
    // context 表示当前组件在树中的位置；查找所在焦点区域并取消焦点以收起键盘。
    FocusScope.of(context).unfocus();
    // 只读取文字判断是否有输入，不保存任务。|| 表示任一条件成立即可。
    // 日期默认就有内容，因此与初始值比较；只修改或清空日期也需要确认丢弃。
    final hasInput =
        _titleController.text.isNotEmpty ||
        _durationController.text.isNotEmpty ||
        _dateController.text != _initialDateText;

    if (hasInput) {
      // showDialog 是打开对话框的函数；<bool> 指定其返回结果的类型。
      // await 等待确认框关闭：继续填写返回 false，放弃返回 true，取消可能为 null。
      final discard = await showDialog<bool>(
        context: context,
        // Flutter 调用 builder 来构建确认框，提供框内的 dialogContext。
        builder: (dialogContext) {
          // AlertDialog 是确认对话框组件，title/content/actions 分别是标题、正文和操作区。
          return AlertDialog(
            // Text 显示文字；const 表示这份固定组件配置可以在编译时确定。
            title: const Text('放弃本次填写？'),
            content: const Text('返回后，已填写的内容不会保存。'),
            actions: [
              // TextButton 是文字按钮；child 指定按钮内容，onPressed 接收点击回调。
              TextButton(
                // => 是单表达式函数的简写；点击时关闭确认框，并返回 false。
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('继续填写'),
              ),
              TextButton(
                // dialogContext 用于找到确认框所在的导航器；这里尚未关闭创建页。
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('放弃填写'),
              ),
            ],
          );
        },
      );
      // await 期间页面可能被移除；mounted 表示 State 是否仍挂在组件树上。
      // ! 表示取反；仅在页面仍存在且明确选择 true 时继续，false/null 都保留输入。
      // discard 在 if (hasInput) 内声明，所以这个判断也必须放在同一作用域中。
      if (!mounted || discard != true) {
        return;
      }
    }

    // 没有输入会跳过上面的判断，因此在最终使用 context 前再检查一次。
    if (!mounted) return;

    // pop 移除导航栈顶部的创建页，显示原来的今天页；此处不写数据库。
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // build 返回组件树。child 接收一个子组件；children 接收多个子组件的列表。
    // PopScope 监听页面返回，保护表单输入；它自身不绘制可见内容。
    return PopScope<void>(
      // 阻止系统直接弹出页面，先由下面的回调询问是否丢弃。
      canPop: false,
      // Flutter 提供 didPop（是否已退出）与 result（路由结果，本页不用）。
      onPopInvokedWithResult: (didPop, result) async {
        // 手动 Navigator.pop 成功后也会通知这里，避免再次发起返回。
        if (didPop) return;
        await _requestClose();
      },
      // Scaffold 提供标准页面骨架：appBar 是顶栏，body 是主体。
      // 默认随键盘调整主体可用高度；下面的列表负责在剩余空间内滚动。
      child: Scaffold(
        appBar: AppBar(
          title: const Text('新建任务'),
          // leading 是顶栏起始侧的位置，这里放返回按钮。
          leading: IconButton(
            // 传入方法本身作为回调，点击时才执行；不要写成 _requestClose()。
            onPressed: _requestClose,
            // Icon 绘制图标，Icons.arrow_back 是 Flutter 提供的返回箭头。
            icon: const Icon(Icons.arrow_back),
            // tooltip 提供长按/悬停提示，也用于辅助功能说明。
            tooltip: '返回',
          ),
        ),
        // SafeArea 避开系统安全区，例如底部手势区域。
        body: SafeArea(
          // ListView 将 children 从上到下排列，空间不足时可滚动。
          child: ListView(
            // EdgeInsets 是内边距配置；fromLTRB 参数依次为左、上、右、下，单位是逻辑像素。
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              const Text('任务名称'),
              // SizedBox 留出固定空白；这里用 height 分隔标签与输入框。
              const SizedBox(height: 8),
              // TextField 是可编辑的文本输入组件，用户输入后会更新关联的控制器。
              TextField(
                controller: _titleController,
                // 将软键盘操作键设为“下一项”，默认编辑行为会尝试转到下一个输入框。
                textInputAction: TextInputAction.next,
                // InputDecoration 是外观配置对象，不是独立的 Widget。
                decoration: const InputDecoration(
                  // hintText 在输入为空时提示示例，不会写进 controller.text。
                  hintText: '例如：阅读 Flutter',
                  // OutlineInputBorder 为输入区域配置轮廓边框。
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              const Text('计划日期'),
              const SizedBox(height: 8),
              TextField(
                // 显示默认日期，并保留用户修改后的文字；保存时再交给业务层校验。
                controller: _dateController,
                // 只是请求日期时间键盘，不保证输入一定是合法日期。
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'YYYY-MM-DD',
                  // helperText 持续显示在输入框下方，说明填写格式。
                  helperText: '例如：2026-10-21',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              const Text('计划时长'),
              const SizedBox(height: 8),
              TextField(
                // 即使请求数字键盘，控制器读取出来的仍然是字符串，例如 '20'。
                controller: _durationController,
                // keyboardType 只是请求数字键盘，不能独自限制粘贴或实体键盘输入。
                keyboardType: TextInputType.number,
                // 格式器过滤输入，仅保留 0–9；不代表业务校验通过，0 仍需在保存时拒绝。
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: '例如：20',
                  // suffixText 在输入区域末尾显示单位，不属于用户输入的字符串。
                  suffixText: '分钟',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
