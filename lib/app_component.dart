import 'package:angular/angular.dart';
import 'package:dev/src/rich_text_editor/rich_text_editor.dart';

@Component(
  selector: 'my-app',
  styleUrls: ['app_component.css'],
  templateUrl: 'app_component.html',
  directives: [
    RichTextEditor,
  ],
)
class AppComponent {}
