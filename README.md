# munin-aircon-by-echonet


## これはなに？

ECHONET に対応したエアコンをmuninでモニターリングします。



## 使い方

通常のmunin-pluginと同じです。
plugins ディレクトリにそのまま置いてください。
各種設定等は、plugin-config.dのmunin-node に記載すべきですが、
そこまで対応していません。

## 設定について
 aircon_eoj.set_values 0x01,0x30,0x03
 m = Main.new("192.168.33.111",aircon_eoj)
の２か所を設定します。
EOJは、モニタリングしたいEOJを指定します。
IPアドレスはエアコンのechonet をしゃべる機器のIPアドレスを指定します。




## その他

うーん。ECHONETはわかると面白い。
めんどなプロトコルをできるだけ隠ぺいしてあるので、
かなり楽とおもいます。


1st versionは、まぁ、とりあえず、こんな感じで。
