---
title: CodingToolTemplateExplain
xcode_version: 26.3
category: generation-tools
resource_kind: prompt-template
source_app: /Volumes/eyedisk/Applications/Xcode.app
source_file: /Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/CodingToolTemplateExplain.idechatprompttemplate
original_filename: CodingToolTemplateExplain.idechatprompttemplate
---

# CodingToolTemplateExplain

Source app: `/Volumes/eyedisk/Applications/Xcode.app`
Source file: `/Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/CodingToolTemplateExplain.idechatprompttemplate`
Category: `generation-tools`
Kind: `prompt-template`

## Extracted Content

I need you to explain the following code selection.

**File**: {{ FilePath }}
**Lines**: {{ StartLine }}-{{ EndLine }}

{% if SelectedCode %}**Selected Code**:
```
{{ SelectedCode }}
```
{% endif %}

Please use the XcodeRead tool to read the full file context if needed, and provide a clear explanation of what this code does, how it works, and any important details about its implementation.
