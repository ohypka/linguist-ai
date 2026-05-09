class CardModel {
  final String sentence;
  final bool isCorrect; // true = correct sentence, false = contains an error

  CardModel({required this.sentence, required this.isCorrect});
}