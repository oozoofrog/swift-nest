---
title: Snippets
xcode_version: 26.3
category: context-and-grounding
resource_kind: prompt-template
source_app: /Volumes/eyedisk/Applications/Xcode.app
source_file: /Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/Snippets.idechatprompttemplate
original_filename: Snippets.idechatprompttemplate
---

# Snippets

Source app: `/Volumes/eyedisk/Applications/Xcode.app`
Source file: `/Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/Snippets.idechatprompttemplate`
Category: `context-and-grounding`
Kind: `prompt-template`

## Extracted Content

The user has included the following code snippets from the files:
{% for snippet in snippets %}
```{{ snippet.language }}
{{ snippet.code }}
```
{% endfor %}
