import '../../models/word.dart';
import 'kdrama.dart';
import 'kpop.dart';
import 'kfood.dart';
import 'manners.dart';
import 'slang.dart';
import 'travel.dart';
export 'kdrama.dart';
export 'kfood.dart';
export 'kpop.dart';
export 'manners.dart';
export 'slang.dart';
export 'travel.dart';

// Alias for backwards compat in theme screens
typedef ThemeWord = Word;

List<Word> getThemeWords(String themeId) {
  switch (themeId) {
    case 'kdrama':  return kdramaWords;
    case 'kpop':    return kpopWords;
    case 'kfood':   return kfoodWords;
    case 'manners': return mannersWords;
    case 'slang':   return slangWords;
    case 'travel':  return travelWords;
    default:        return [];
  }
}
