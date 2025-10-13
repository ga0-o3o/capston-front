import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonGrid extends StatelessWidget {
  final int itemCount;
  final double borderRadius;
  final double topPadding;
  final double childAspectRatio;
  final double? height;
  final double searchHeight; // 검색창 네모 높이

  const SkeletonGrid({
    Key? key,
    this.itemCount = 6,
    this.borderRadius = 12,
    this.topPadding = 34,
    this.childAspectRatio = 3 / 2,
    this.height,
    this.searchHeight = 50, // 기본 검색창 높이
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, topPadding, 12, 12),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          children: [
            // 🔹 검색창 모양 네모
            Container(
              height: searchHeight,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            const SizedBox(height: 30),
            // 🔹 Grid 박스
            Expanded(
              child: GridView.builder(
                itemCount: itemCount,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
                ),
                itemBuilder: (context, index) {
                  return Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
