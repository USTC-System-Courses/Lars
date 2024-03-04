import 'dart:html' as html;

void downloadTxtFile(String name, String textList) {
    // 将 List<String> 转换为一个字符串，每个元素占据一行;
    String content = textList;

    // 创建一个 Blob 对象
    var blob = html.Blob([content], 'text/plain');

    // 创建一个临时 URL 对象
    var url = html.Url.createObjectUrlFromBlob(blob);

    // 创建一个 <a> 元素
    var anchor = html.AnchorElement(href: url);
        // ..setAttribute('download', name)
        // ..click();
    anchor.setAttribute('download', name);
    anchor.href = url;
    anchor.download = null;
    anchor.click();
    // 释放 URL 对象
    html.Url.revokeObjectUrl(url);
    
    // 释放 anchor 对象
    anchor.remove();
}