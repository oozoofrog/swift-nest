---
title: AgentAdditionalContext
xcode_version: 26.3
category: context-and-grounding
resource_kind: prompt-template
source_app: /Volumes/eyedisk/Applications/Xcode.app
source_file: /Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AgentAdditionalContext.idechatprompttemplate
original_filename: AgentAdditionalContext.idechatprompttemplate
---

# AgentAdditionalContext

Source app: `/Volumes/eyedisk/Applications/Xcode.app`
Source file: `/Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AgentAdditionalContext.idechatprompttemplate`
Category: `context-and-grounding`
Kind: `prompt-template`

## Extracted Content

{% if projectStructure %}Project structure:
{{ projectStructure }}{% endif %}{% if currentFile %}

The user is currently inside this file: {{ currentFile.filePath }}{% if currentFile.selection %}

The user has selected the following code from that file (lines {{ currentFile.selection.startLine }}-{{ currentFile.selection.endLine }}):
{{ currentFile.selection.text }}{% else %}

The user has no code selected.{% endif %}{% else %}

The user has no file currently open.{% endif %}
