import 'package:flutter/material.dart';

class VaultProvider extends ChangeNotifier {
  // This list holds all the images the user decides to save
  final List<String> _savedImages = [];

  // A getter to allow screens to read the data
  List<String> get savedImages => _savedImages;

  // A function to add a new image to the vault
  void addImageToVault(String imageUrl) {
    _savedImages.add(imageUrl);
    // This is the magic line: it tells all screens looking at this data to update instantly!
    notifyListeners(); 
  }
}