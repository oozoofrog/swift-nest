---
title: ContextItems
xcode_version: 26.3
category: context-and-grounding
resource_kind: prompt-template
source_app: /Volumes/eyedisk/Applications/Xcode.app
source_file: /Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/ContextItems.idechatprompttemplate
original_filename: ContextItems.idechatprompttemplate
---

# ContextItems

Source app: `/Volumes/eyedisk/Applications/Xcode.app`
Source file: `/Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/ContextItems.idechatprompttemplate`
Category: `context-and-grounding`
Kind: `prompt-template`

## Extracted Content

The user has provided the following miscellaneous context that may be useful to answer their question:
{% for contextItem in contextItems %}
```
{{ contextItem.code }}
```
{% endfor %}
