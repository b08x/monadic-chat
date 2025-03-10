# FAQ：機能の追加

**Q**: Ollamaのプラグインを導入して、モデルをダウンロードしましたが、webインターフェイスに反映されません。どうしたらいいですか？

**A**:  Ollamaコンテナにダウンロードしたモデルはロードされて使用可能になるまでに少し時間がかかる場合があります。少し待ってから、webインターフェイスをリロードしてください。それでもダウンロードしたモデルが表示されない場合は、ターミナルからOllamaコンテナにアクセスして、`ollama list` コマンドを実行して、ダウンロードしたモデルがリストに表示されているか確認してください。表示されていない場合は、`ollama reload` コマンドを実行して、Ollamaのプラグインを再読み込みしてください。

---

**Q**: Python コンテナに新たなプログラムやライブラリを追加するにはどうすればいいですか？

**A**: いくつかの方法がありますが、共有フォルダ内の `pysetup.sh` にインストールスクリプトを追加して、Monadic Chat の環境構築時にライブラリをインストールする方法が便利です。[ライブラリの追加](./python-container?id=ライブラリの追加) および [pysetup.sh の利用](./python-container?id=pysetupsh-の利用) を参照してください。
