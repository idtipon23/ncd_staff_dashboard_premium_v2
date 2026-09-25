import 'package:flutter/material.dart';

class ResizableClinicalDialog extends StatefulWidget {
  final Widget child;
  final double minWidth;
  final double minHeight;
  final bool startMaximized; // ตั้งค่าให้เปิดมาเต็มจอไว้ก่อน

  const ResizableClinicalDialog({
    super.key,
    required this.child,
    this.minWidth = 650,
    this.minHeight = 500,
    this.startMaximized = true, // ค่าเริ่มต้น: ขยายเต็มจอทันที
  });

  @override
  State<ResizableClinicalDialog> createState() => _ResizableClinicalDialogState();
}

class _ResizableClinicalDialogState extends State<ResizableClinicalDialog> {
  late bool _isMaximized;
  double? _width;
  double? _height;

  @override
  void initState() {
    super.initState();
    _isMaximized = widget.startMaximized;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    // กำหนดขนาด: ถ้าเต็มจอให้กินพื้นที่ 96% ของเบราว์เซอร์ ถ้าไม่ใช่ให้ใช้ขนาดที่ผู้ใช้ลากไว้
    final currentWidth = _isMaximized
        ? screenSize.width * 0.96
        : (_width ?? (screenSize.width * 0.85)).clamp(widget.minWidth, screenSize.width * 0.98);

    final currentHeight = _isMaximized
        ? screenSize.height * 0.94
        : (_height ?? (screenSize.height * 0.85)).clamp(widget.minHeight, screenSize.height * 0.96);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: Container(
          width: currentWidth,
          height: currentHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
          ),
          child: Stack(
            children: [
              // 1. เนื้อหาหลักของ Dialog (Form บันทึก / OPD Workspace)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: widget.child,
                ),
              ),

              // 2. ปุ่ม Maximize / Restore สลับเต็มจอ-ย่อขนาด (มุมขวาบน)
              Positioned(
                top: 14,
                right: 50,
                child: IconButton(
                  tooltip: _isMaximized ? 'ย่อขนาดหน้าต่าง' : 'ขยายเต็มจอ',
                  icon: Icon(
                    _isMaximized ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                    color: const Color(0xFF64748B),
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() {
                      _isMaximized = !_isMaximized;
                      if (!_isMaximized && _width == null) {
                        _width = screenSize.width * 0.8;
                        _height = screenSize.height * 0.8;
                      }
                    });
                  },
                ),
              ),

              // 3. ขอบขวา (Drag ขยายความกว้าง ซ้าย-ขวา)
              Positioned(
                top: 20,
                bottom: 20,
                right: 0,
                width: 10,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _isMaximized = false;
                        _width = (currentWidth + details.delta.dx)
                            .clamp(widget.minWidth, screenSize.width * 0.98);
                      });
                    },
                  ),
                ),
              ),

              // 4. ขอบล่าง (Drag ขยายความสูง บน-ล่าง)
              Positioned(
                left: 20,
                right: 20,
                bottom: 0,
                height: 10,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpDown,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (details) {
                      setState(() {
                        _isMaximized = false;
                        _height = (currentHeight + details.delta.dy)
                            .clamp(widget.minHeight, screenSize.height * 0.96);
                      });
                    },
                  ),
                ),
              ),

              // 5. มุมขวาล่าง (Drag ขยายทั้งกว้างและสูงพร้อมกัน)
              Positioned(
                right: 0,
                bottom: 0,
                width: 22,
                height: 22,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeDownRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (details) {
                      setState(() {
                        _isMaximized = false;
                        _width = (currentWidth + details.delta.dx)
                            .clamp(widget.minWidth, screenSize.width * 0.98);
                        _height = (currentHeight + details.delta.dy)
                            .clamp(widget.minHeight, screenSize.height * 0.96);
                      });
                    },
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.south_east_rounded,
                          size: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}