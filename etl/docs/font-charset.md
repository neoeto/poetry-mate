# 字体子集字符集说明

`font-charset.txt` = 霞鹜文楷子集的覆盖字符集(v2):
**出货简体文本 ∪ 原文字符 ∪ ASCII/中文标点**(共 15,740 字符)。

## 为什么需要两份来源
繁转简会产生原文中不存在的简化字(癘→疠、礦→矿)。
只用原文字符做子集,会导致转换后的常用字缺字形(首版踩坑: 种子集缺 20 字)。

## 再生成步骤
```bash
# 1. 提取字符集(etl/ 下运行, 逻辑见 DEPLOYMENT 手册引用)
#    来源A: dist-full/<version>/volumes/*/*.json.zst 的 paragraphs/title/author/rhythmic/preface
#    来源B: work/snapshot-*/全唐诗+宋词 原始记录同字段
# 2. 子集化(需 pip install fonttools)
pyftsubset /tmp/wenkai-full.ttf --text-file=font-charset.txt \
  --output-file=app/assets/fonts/LXGWWenKaiGB-Regular.ttf --layout-features='*'
```
