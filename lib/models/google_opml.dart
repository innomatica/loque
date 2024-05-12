class GoogleOpml {
  String? xmlUrl;
  String? type;
  String? text;

  GoogleOpml(this.xmlUrl, this.type, this.text);

  @override
  String toString() => 'xmlUrl:$xmlUrl, type:$type, text:$text';
}
