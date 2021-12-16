import 'dart:html';

class RichTextUtils {
  /// paste Html at caret
  /// [board] destination stage where the HTML content will be pasted
  /// [html] content to added
  /// [selectPastedContent] select pasted content?
  static void pasteHtmlAtCaret(HtmlElement board, dynamic html,
      {bool selectInnerContent = false, bool selectPastedContent = false}) {
    board.focus();
    var sel = window.getSelection();
    Range range;

    //var textSelected = sel.toString();
    if (sel.rangeCount != 0) {
      range = sel.getRangeAt(0);
      range.deleteContents();

      // Range.createContextualFragment() would be useful here but is
      // only relatively recently standardized and is not supported in
      // some browsers (IE9, for one)
      Node firstNode, lastNode;
      if (html is String) {
        final el = document.createElement('div');
        el.innerHtml = html;
        var frag = document.createDocumentFragment();
        Node node;
        while ((node = el.firstChild) != null) {
          lastNode = frag.append(node);
        }
        firstNode = frag.firstChild;
        range.insertNode(frag);
      } else {
        firstNode = html;
        lastNode = html;
        range.insertNode(html);
      }

      // Preserve the selection
      if (lastNode != null) {
        if (selectPastedContent == true) {
          range = range.cloneRange();
          range.setStartBefore(firstNode);
          sel.removeAllRanges();
          sel.addRange(range);
        } else if (selectInnerContent == true) {
          print('pasteHtmlAtCaret ${lastNode.firstChild}');
          var range = document.createRange();
          range.selectNodeContents(lastNode.firstChild);
          var sel = window.getSelection();
          sel.removeAllRanges();
          sel.addRange(range);
        } else {
          range = range.cloneRange();
          range.setStartAfter(lastNode);
          range.collapse(true);
          sel.removeAllRanges();
          sel.addRange(range);
        }
      }
    }
  }

  static DocumentFragment htmlToFragment(String html) {
    final el = document.createElement('div');
    el.innerHtml = html;
    var frag = document.createDocumentFragment();
    Node node;
    while ((node = el.firstChild) != null) {
      frag.append(node);
    }
    return frag;
  }

  /// verifica se um Node esta contido em um Node recursivamente (deep)
  static bool isDescendant(Node parent, Node child) {
    var node = child.parentNode;
    while (node != null) {
      if (node == parent) {
        return true;
      }
      node = node.parentNode;
    }
    return false;
  }

  static List<dynamic> htmlToFragmentAndLastNode(String html) {
    final el = document.createElement('div');
    el.innerHtml = html;
    var frag = document.createDocumentFragment();
    Node node, lastNode;
    while ((node = el.firstChild) != null) {
      lastNode = frag.append(node);
    }
    return [frag, lastNode];
  }

  /// coloca o cursos no inicio de um elemento
  ///[offset] em que caractere vai estar o cursor
  static void setCaret(HtmlElement board, HtmlElement targetEle, [int offset = 1]) {
    if (targetEle != null) {
      //board.focus();
      var range = document.createRange();
      var sel = window.getSelection();
      range.setStart(targetEle, offset);
      range.collapse(true);
      sel.removeAllRanges();
      sel.addRange(range);
    }
  }

  /// get the last child of a deep one
  /// obtem o ultimo filho de um no profundamente
  static Node getLastChild(Node node) {
    var re = node;
    if (node.hasChildNodes()) {
      for (var el in node.childNodes) {
        re = getLastChild(el);
      }
    }
    return re;
  }

  /// get the html element where the typing cursor is
  /// obtem o elemento html de onde esta o cursor de digitação
  static HtmlElement getNodeFromSelectionStart() {
    var node = window.getSelection().anchorNode;
    return (node.nodeType == 3 ? node.parentNode : node);
  }

  /// Imput this:
  /// <div id="my_example_id" class="ShinyClass">
  ///   My important text
  ///   <span> Here</span>
  /// </div>
  /// Output this:
  /// <div id="my_example_id" class="ShinyClass">
  static String getHtmlElementAsStringWithoutChildren(HtmlElement input) {
    // make a copy of the element
    var clone = input.clone(false) as HtmlElement;
    // empty all the contents of the copy
    clone.innerHtml = '';
    // get the outer html of the copy
    return clone.outerHtml;
    /**
     * var element = document.querySelector(selector)
    var htmlText = element.outerHTML
    var start  = htmlText.search(/</)
    var end  = htmlText.search(/>/)
    return htmlText.substr(start, end + 1)
      */
  }

  static void closeParentAndInsertTextOnIndex(
      HtmlElement board, Text inputText, HtmlElement nodeSelected, int indexOfCaret) {
    var currentHtmlStr = nodeSelected.outerHtml;
    var index = getHtmlElementAsStringWithoutChildren(nodeSelected).length - 3 - nodeSelected.tagName.length;
    index = index + indexOfCaret;
    var a = currentHtmlStr.substring(0, index);
    var b = currentHtmlStr.substring(index + inputText.length, currentHtmlStr.length);
    currentHtmlStr = '$a</${nodeSelected.tagName}>$inputText<${nodeSelected.tagName}>$b';
    var list = htmlToFragmentAndLastNode(currentHtmlStr);
    nodeSelected.replaceWith(list.first);
    //colocar o cursos no final do inputText
    var range = document.createRange();
    var sel = window.getSelection();
    range.setStart(list.last, 0);
    range.collapse(true);
    sel.removeAllRanges();
    sel.addRange(range);
  }

  static Node closeParentAndInsertHtmlAtCaret(HtmlElement board, HtmlElement inputHtml, HtmlElement nodeSelected) {
    inputHtml.id = 's1234';
    var from = inputHtml.outerHtml;
    var currentHtmlStr = nodeSelected.outerHtml;
    var to = '</${nodeSelected.tagName}>$from<${nodeSelected.tagName}>';
    currentHtmlStr = currentHtmlStr.replaceFirst(from, to);
    var frag = htmlToFragment(currentHtmlStr);
    nodeSelected.replaceWith(frag);
    var span = document.getElementById('s1234');
    setCaret(board, span);
    span.attributes.remove('id');
    return span;
  }

  //Now the caret (the blinking cursor)
  static void insertHtmlAtCaret(HtmlElement board, HtmlElement inputHtml) {
    board.focus();
    Node lastNode;
    var sel = window.getSelection();
    //var textSelected = sel.toString();
    var range = sel.getRangeAt(0);
    range.deleteContents();

    var nodeSelected = getNodeFromSelectionStart();

    if (nodeSelected == board) {
      lastNode = inputHtml;
      range.insertNode(inputHtml);
    } else {
      if (inputHtml.tagName == nodeSelected.tagName) {
        lastNode = Text(inputHtml.text);
        range.insertNode(lastNode);
      } else if (inputHtml.tagName == 'SPAN') {
        range.insertNode(inputHtml);

        var tags = ['B', 'I', 'U'];
        if (tags.contains(nodeSelected.tagName)) {
          closeParentAndInsertHtmlAtCaret(board, inputHtml, nodeSelected);
        }
      } else {
        range.insertNode(inputHtml);
        lastNode = inputHtml;
      }
    }
    setCaret(board, lastNode);
    // Preserve the selection
    /*if (lastNode != null) {
   
      range = range.cloneRange();
      //range.setStartAfter(lastNode);
      range.setStart(lastNode, 1);
      range.collapse(true);
      sel.removeAllRanges();
      sel.addRange(range);
      //sel.collapse(lastNode, 1);

    }*/
  }

  static List<String> get foregroundColors => [
        '#08ba9c',
        '#0a9e85',
        '#28c972',
        '#22ac61',
        '#2a99da',
        '#9b5db6',
        '#2c3e50',
        '#7e8c8d',
        '#c23c2c',
        '#e9503d',
        '#f3c319',
        '#fff',
        '#000',
        'blue',
        'red',
        '#4e0a77',
        'BlanchedAlmond',
        'Brown',
        'BlueViolet',
        'crimson'
      ];
}
