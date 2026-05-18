import 'dart:io';

void main() async {
  final dir = Directory('lib');
  final files = await dir.list(recursive: true).where((e) => e is File && e.path.endsWith('.dart')).toList();
  
  // Part 2: fix withOpacity
  for (var entity in files) {
    if (entity is File) {
      String content = await entity.readAsString();
      if (content.contains('.withOpacity(')) {
        content = content.replaceAllMapped(RegExp(r'\.withOpacity\((.*?)\)'), (match) {
          return '.withValues(alpha: ${match.group(1)})';
        });
        await entity.writeAsString(content);
        print('Updated withOpacity in ${entity.path}');
      }
    }
  }

  // Part 1: Rename files
  Map<String, String> renames = {};
  for (var entity in files) {
    if (entity is File) {
      String name = entity.uri.pathSegments.last;
      if (name.startsWith('talentTrail_')) {
        String newName = name.replaceFirst('talentTrail_', 'talent_trail_');
        renames[name] = newName;
        
        String newPath = entity.path.replaceFirst(name, newName);
        await entity.rename(newPath);
        print('Renamed $name to $newName');
      }
    }
  }

  // Update imports
  if (renames.isNotEmpty) {
    final updatedFiles = await dir.list(recursive: true).where((e) => e is File && e.path.endsWith('.dart')).toList();
    for (var entity in updatedFiles) {
      if (entity is File) {
        String content = await entity.readAsString();
        bool changed = false;
        for (var oldName in renames.keys) {
          if (content.contains(oldName)) {
            content = content.replaceAll(oldName, renames[oldName]!);
            changed = true;
          }
        }
        if (changed) {
          await entity.writeAsString(content);
          print('Updated imports in ${entity.path}');
        }
      }
    }
  }
}
