import 'package:flutter/material.dart';

class WordbookCard extends StatelessWidget {
  final Map<String, dynamic> book;
  final VoidCallback onTap;

  const WordbookCard({super.key, required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0),
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(book['image']),
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
            ),
          ),
          child: Align(
            alignment: const Alignment(0, -0.2),
            child: Text(
              book['title'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
