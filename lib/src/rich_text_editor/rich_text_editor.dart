import 'dart:async';
import 'dart:js';

import 'package:angular/angular.dart';
import 'package:angular_forms/angular_forms.dart';

import 'dart:html';

import './rich_text_utils.dart';

enum ActionType { formatter, other }

class EditorAction {
  String icon;
  String label;
  String cmd; //bold | italic
  ActionType type;
  bool active = false;
  String tag;
  bool selected = false;
  HtmlElement Function() buildElement;
  void Function(EditorAction action, Event event) onClick;

  EditorAction(
      {this.cmd,
      this.label,
      this.icon,
      this.buildElement,
      this.type,
      this.tag,
      this.onClick,
      this.active = false});
}

@Component(
    selector: 'richtexteditor',
    templateUrl: 'rich_text_editor.html',
    styleUrls: [
      'rich_text_editor.css'
    ],
    directives: [
      formDirectives,
      coreDirectives,
    ],
    pipes: [
      commonPipes
    ],
    providers: [
      ExistingProvider.forToken(ngValueAccessor, RichTextEditor),
    ])
class RichTextEditor
    implements ControlValueAccessor<String>, OnDestroy, AfterViewInit {
  //final NgControl ngControl;
  StreamSubscription ssControlValueChanges;

  StreamSubscription globalClickSS;

  List<EditorAction> actions = [];
  bool isCodeView = false;
  bool isInsertNode;
  @ViewChild('board')
  DivElement board;

  @ViewChild('toolbar')
  HtmlElement toolbar;

  /// html element a ser inserido
  HtmlElement currentNodeToInserted;

  Node currentBoard;

  @ViewChild('codeView')
  TextAreaElement codeView;

  /// contrutor
  RichTextEditor() {
    actions = [
      
      EditorAction(
        label: 'Remover Formatação',
        cmd: 'remove-format',
        icon: 'fa-remove-format',
        type: ActionType.other,
        onClick: removeFormatting,
      ),
      EditorAction(
        label: 'Bold',
        cmd: 'bold',
        icon: 'fa-bold',
        tag: 'b',
        buildElement: () => document.createElement('b'),
        type: ActionType.formatter,
        onClick: applyCustomFormatting,
      ),
      EditorAction(
        label: 'Italic',
        cmd: 'italic',
        icon: 'fa-italic',
        tag: 'i',
        buildElement: () => document.createElement('i'),
        type: ActionType.formatter,
        onClick: applyCustomFormatting,
      ),
      EditorAction(
        label: 'Underline',
        cmd: 'underline',
        icon: 'fa-underline',
        tag: 'u',
        buildElement: () => document.createElement('u'),
        type: ActionType.formatter,
        onClick: applyCustomFormatting,
      ),
      EditorAction(
        label: 'Titulo 1',
        cmd: 'h1',
        icon: 'fa-heading',
        tag: 'h1',
        buildElement: () => document.createElement('h1'),
        type: ActionType.formatter,
        onClick: applyCustomFormatting,
      ),
      EditorAction(
        label: 'Inserir Link',
        cmd: 'link',
        icon: 'fa-link',
        tag: 'a',
        buildElement: () => AnchorElement(),
        type: ActionType.other,
        onClick: insertLink,
      ),
      EditorAction(
        label: 'Cor do texto',
        cmd: 'font-color',
        icon: 'fa-fill-drip',
        type: ActionType.other,
        onClick: applyColorToSelectedText,
      ),
      EditorAction(
        label: 'Ver codigo HTML',
        cmd: 'view-code',
        icon: 'fa-code',
        type: ActionType.other,
        onClick: viewCodeToggle,
      ),
    ];
  }

  TouchFunction onTouchedControlValueAccessor = () {};

  @override
  void onDisabledChanged(bool isDisabled) {}

  /// função a ser chamada para notificar e modificar o modelo vinculado pelo ngmodel
  ChangeFunction<String> onChangeControlValueAccessor =
      (String _, {String rawValue}) {};

  /// Defina a função a ser chamada quando o controle recebe um evento de alteração.
  /// Set the function to be called when the control receives a change event.
  @override
  void registerOnChange(ChangeFunction<String> fn) {
    onChangeControlValueAccessor = fn;
  }

  @override
  void registerOnTouched(f) {
    onTouchedControlValueAccessor = f;
  }

  /// Writes a new item to the element.
  /// @param value the value
  @override
  void writeValue(String v) {
    value = v;
  }

  String _value = '';
  String get value {
    _value = board.innerHtml;
    return _value;
  }

  set value(String v) {
    _value = v;
    board.setInnerHtml(v,
        validator: NodeValidator(), treeSanitizer: NodeTreeSanitizer.trusted);
  }

  void disableFormatters() {
    activeFormatters.forEach((e) {
      e.active = false;
      e.selected = false;
    });
    currentNodeToInserted = getNoFormatElement();
    currentBoard = board;
    isInsertNode = false;
  }

  //atualizarMundancas no Modelo ou  na variavel vinculada via NgModel a este componente
  void updateModelChanges() {
    onChangeControlValueAccessor(value);
  }

  /*Selection getSelection() {
    isCodeView ? codeView.focus() : board.focus();
    return window.getSelection();
  }*/

  bool isSelection() {
    var sel = window.getSelection();
    var textSel = sel.toString();
    if (textSel.isNotEmpty) {
      return true;
    }
    return false;
  }

  HtmlElement getNoFormatElement() {
    return SpanElement()
      ..text = '\u2002'
      ..style.color = currentColor
      ..classes.add('no-format');
  }

  void removeAllDropdownColor() {
    document.body
        .querySelectorAll('.drop-foreground-color')
        ?.forEach((d) => d.remove());
    isDropdownColorOpen = false;
  }

  bool isDropdownColorOpen = false;
  String currentColor = '';

  /// Aplica cor ao texto selecionado
  void applyColorToSelectedText(EditorAction action, Event event) {
    event.preventDefault();
    var sel = window.getSelection(); //seleção atual
    var textSel = sel.toString(); //texto selecionado
    var selNode = sel.anchorNode; //elemento onde esta o texto selecionado
    var selRange = sel.getRangeAt(0);
    // action.active = !action.active;
    isDropdownColorOpen = false;
    var btn = toolbar.querySelector('[data-command="${action.cmd}"]');
    btn.onClick.listen((e) => e.stopPropagation());
    var dropDiv = btn.parent.querySelector('.drop-foreground-color');
    if (dropDiv == null) {
      dropDiv = DivElement()..classes.add('drop-foreground-color');
      dropDiv.onClick.listen((e) => e.stopPropagation());
      var ul = UListElement()..classes.add('color-palette'); //UListElement
      ul.onClick.listen((e) => e.stopPropagation());
      RichTextUtils.foregroundColors.forEach((color) {
        var li = document.createElement('li')..classes.add('item'); //LIElement
        li.style.backgroundColor = color;

        li.onMouseDown.listen((e) {
          e.stopPropagation();
          e.preventDefault();
          currentColor = color;
          if (isCodeView == false) {
            if (textSel.isNotEmpty) {
              if (sel.rangeCount != 0) {
                if (selNode.parent.text == textSel) {
                  selNode.parent.style.color = color;
                } else {
                  selRange.deleteContents();
                  var span = SpanElement();
                  span.text = textSel;
                  span.style.color = color;
                  selRange.insertNode(span);
                }
              }
            }
          }
          isDropdownColorOpen = false;
          dropDiv.remove();
        });

        ul.append(li);
      });
      dropDiv.append(ul);
      btn.parent.append(dropDiv);
      Future.delayed(Duration(milliseconds: 200))
          .then((value) => isDropdownColorOpen = true);
    } else {
      isDropdownColorOpen = false;
      dropDiv.remove();
    }
  }

  void applyFormatting(EditorAction action, Event event) {
    action.active = !action.active;
    document.execCommand(action.cmd, false, '');
  }

  void applyCustomFormatting(EditorAction action, Event event) {
    event.preventDefault();
    if (isCodeView == false) {
      action.active = !action.active;
      if (activeFormatters.isEmpty) {
        currentNodeToInserted = getNoFormatElement();
      } else {
        var formatters = activeFormatters;
        var tree = formatters[0].buildElement();
        for (var i = 1; i < formatters.length; i++) {
          var deep = RichTextUtils.getLastChild(tree);
          deep.append(formatters[i].buildElement());
        }
        //consoleLog(tree);
        currentNodeToInserted = tree;
      }
      currentBoard = board;
      board.focus();
      var sel = window.getSelection();
      print('seleção $sel');
      var textSel = sel.toString();
      if (textSel.isNotEmpty) {
        if (sel.rangeCount != 0) {
          if (sel.focusNode.parent.tagName.toLowerCase() != action.tag) {
            var range = sel.getRangeAt(0);
            range.deleteContents();
            currentNodeToInserted.text = textSel;
            currentNodeToInserted.style.color = currentColor;
            range.insertNode(currentNodeToInserted);
            updateModelChanges();
          }
          disableFormatters();
        }
      }

      if (textSel.isEmpty && isCodeView == false) {
        isInsertNode = true;
      }
    }
  }

  void removeFormatting(EditorAction action, Event event) {
    event.preventDefault();
    /*var sel = getSelection();
    var textSel = sel.toString();
    if (textSel.isNotEmpty) {
      if (sel.rangeCount != 0) {
        if (isViewCode == false) {
          var range = sel.getRangeAt(0);
          var nodeToDeleted = sel.anchorNode.parent;
          var textOfEle = nodeToDeleted.innerText;

          if (board.contains(nodeToDeleted) && nodeToDeleted != board) {
            if (textSel == textOfEle) {
              nodeToDeleted.remove();
              range.insertNode(Text('')..text = textSel);
            } else {
              RichTextUtils.closeParentAndInsertTextOnIndex(
                  board, Text('')..text = textSel, nodeToDeleted, range.startOffset);
            }
            updateModelChanges();
            disableFormatters();
          }
        }
      }
    }*/

    var node = RichTextUtils.getNodeFromSelectionStart();
    if (board.contains(node) && node != board) {
      node.replaceWith(Text('')..text = node.innerText);
      updateModelChanges();
      disableFormatters();
    }
  }

  void insertLink(EditorAction action, Event event) {
    event.preventDefault();
    action.active = true;
    var result = context.callMethod(
        'prompt', ['Digite a URL iniciando com http://', 'http://']);
    var a = action.buildElement() as AnchorElement;
    a.href = result;
    a.target = '_blank';
    a.text = 'Link';

    ///a.appendHtml('<b>Link</b>');
    RichTextUtils.pasteHtmlAtCaret(board, a);
    action.active = false;
  }

  void viewCodeToggle(EditorAction action, Event event) {
    event.preventDefault();
    action.active = !action.active;
    isCodeView = !isCodeView;
    if (isCodeView) {
      codeView.value = value;
    }
  }

  void updateValueFromCodeView() {
    var v = codeView.value;
    print('v $v');
    value = v;
    updateModelChanges();
  }

  /// formatadores aplicados no momento
  List<EditorAction> get activeFormatters =>
      actions.where((c) => c.active && c.type == ActionType.formatter).toList();

  // -------------------------------- Start Events --------------------------------------
  void boardKeydownHandler(e) {
    if (e is KeyboardEvent) {
      if (isInsertNode == true) {
        if (e.keyCode > 61 &&
            e.keyCode < 255 &&
            currentNodeToInserted != null) {
          isInsertNode = false;
          RichTextUtils.getLastChild(currentNodeToInserted).text = e.key;

          RichTextUtils.insertHtmlAtCaret(board, currentNodeToInserted);
          //isto é para não replicar o caracter digitado
          e.preventDefault();
        }
      }
      if (e.keyCode == KeyCode.DELETE) {
        if (isSelection()) {
          var sel = window.getSelection();
          if (sel.toString().length != board.innerText.length) {
            //DELETE selection
            sel.deleteFromDocument();
          } else {
            //'DELETE all
            value = '';
          }
          disableFormatters();
          e.preventDefault();
        }
      }
    }
  }

  void boardKeyupHandler(e) {
    if (e is KeyboardEvent) {
      if (e.keyCode == KeyCode.BACKSPACE) {
        if (board.innerText.trim() == '' || value == '<br>') {
          value = ''; //\u2002
          disableFormatters();
        }
      }
    }
    updateModelChanges();
  }

  void boardClickHandler(MouseEvent event) {
    var el = event.target as Node;
    HtmlElement rootElement = el;
    var control = true;
    actions.forEach((ac) => ac.selected = false);

    if (el != board) {
      var index = 0;
      while (control) {
        switch (rootElement.tagName.toLowerCase()) {
          case 'b':
            actions.where((ac) => ac.tag == 'b').first.selected = true;
            break;
          case 'i':
            actions.where((ac) => ac.tag == 'i').first.selected = true;
            break;
          case 'u':
            actions.where((ac) => ac.tag == 'u').first.selected = true;
            break;
        }

        if (rootElement == board || index == 5) {
          control = false;
        }
        rootElement = el.parent;
        index++;
      }
    }
  }

// -------------------------------- End Events --------------------------------------
  @override
  void ngAfterViewInit() {
    globalClickSS = document.body.onClick.listen((e) {
      if (isDropdownColorOpen) {
        removeAllDropdownColor();
      }
    });
  }

  @override
  void ngOnDestroy() {
    ssControlValueChanges?.cancel();
    globalClickSS?.cancel();
  }
}
