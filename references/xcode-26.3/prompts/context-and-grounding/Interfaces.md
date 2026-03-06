---
title: Interfaces
xcode_version: 26.3
category: context-and-grounding
resource_kind: prompt-template
source_app: /Volumes/eyedisk/Applications/Xcode.app
source_file: /Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/Interfaces.idechatprompttemplate
original_filename: Interfaces.idechatprompttemplate
---

# Interfaces

Source app: `/Volumes/eyedisk/Applications/Xcode.app`
Source file: `/Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/Interfaces.idechatprompttemplate`
Category: `context-and-grounding`
Kind: `prompt-template`

## Extracted Content

The user has also provided the following Swift interfaces that may be useful to answer their question:
{% for interface in interfaces %}
```{{ interface.language }}
{{ interface.code }}
```
{% endfor %}
