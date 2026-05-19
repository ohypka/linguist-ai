import 'package:flutter/material.dart';

class GameCard extends StatelessWidget {
  final Widget child;

  final double positionX;
  final double positionY;
  final double angle;

  final bool showOverlay;
  final Color overlayColor;
  final IconData overlayIcon;

  final Function(DragUpdateDetails)? onPanUpdate;
  final Function(DragEndDetails)? onPanEnd;

  const GameCard({
    super.key,
    required this.child,
    this.positionX = 0,
    this.positionY = 0,
    this.angle = 0,
    this.showOverlay = false,
    this.overlayColor = Colors.green,
    this.overlayIcon = Icons.check,
    this.onPanUpdate,
    this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      child: Transform.translate(
        offset: Offset(positionX, positionY),
        child: Transform.rotate(
          angle: angle,
          child: Stack(
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.height * 0.6,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 30,
                    )
                  ],
                ),
                child: child,
              ),

              if (showOverlay)
                Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.height * 0.6,
                  decoration: BoxDecoration(
                    color: overlayColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Icon(
                      overlayIcon,
                      size: 80,
                      color: Colors.white,
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