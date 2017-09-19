# media_backup

## 概要

メディアのバックアップ

## 使用方法

### media_backup.sh, split_iso_postgap.sh, media_backup_chksum.sh

* 上記で紹介したツールの使用方法に関しては、
  [howto.txt ファイル](https://github.com/yuksiy/media_backup/blob/master/howto.txt)
  を参照してください。

* 上記で紹介したツールの詳細については、「ツール名 --help」を参照してください。

## 動作環境

OS:

* Linux
* Cygwin

依存パッケージ または 依存コマンド:

* make (インストール目的のみ)
* realpath
* cdparanoia
* cdrdao (cdrdao,toc2cueコマンド)
* cdrkit (isoinfo,readomコマンド)
* libcdio (cd-infoコマンド)
* bchunk
* [common_sh](https://github.com/yuksiy/common_sh)
* [find_sort_pl](https://github.com/yuksiy/find_sort_pl)

## インストール

ソースからインストールする場合:

    (Linux, Cygwin の場合)
    # make install

fil_pkg.plを使用してインストールする場合:

[fil_pkg.pl](https://github.com/yuksiy/fil_tools_pl/blob/master/README.md#fil_pkgpl) を参照してください。

## インストール後の設定

環境変数「PATH」にインストール先ディレクトリを追加してください。

## 最新版の入手先

<https://github.com/yuksiy/media_backup>

## License

MIT License. See [LICENSE](https://github.com/yuksiy/media_backup/blob/master/LICENSE) file.

## Copyright

Copyright (c) 2013-2017 Yukio Shiiya
