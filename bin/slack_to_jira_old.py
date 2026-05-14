#!/usr/bin/env python3

# """
# slack_to_jira.py
#
# Usage:
#     python slack_to_jira.py [input_file]
#
# If input_file is omitted, reads from stdin.
#
# Converts a Slack-markup message to Jira-formatted text with:
#  - Slack triple-backtick code blocks -> Jira {code} blocks
#  - Slack inline code patterns wrapped in backticks -> Jira {code}<language?>...{code}
#  - Keeps @mentions as-is (optionally map to Jira users via map_mention)
#  - Keeps plain URLs
#  - Basic normalization of lists and newlines
# """
#
# import re
# import sys
# from typing import Optional
#
# # If you want to map Slack handles to Jira account names or keys, fill this dict.
# MENTION_MAP = {
#     # 'shantanu': 'shantanu.jira',
#     # 'nickh': 'nick.h',
# }
#
# def map_mention(token: str) -> str:
#     """
#     Convert Slack mention token like '@shantanu' to Jira mention.
#     By default returns the token unchanged. Update MENTION_MAP to change.
#     """
#     name = token.lstrip('@')
#     jira = MENTION_MAP.get(name)
#     if jira:
#         return f'@{jira}'
#     return token
#
# def convert_code_blocks(text: str) -> str:
#     """
#     Convert Slack triple-backtick code blocks to Jira {code}...{code}.
#     Handles both: ```...``` and /`/`/.../`/`/ (escaped in your example).
#     Also converts inline single-backtick code to Jira inline code using {code:inline=true}...{code}.
#     """
#     # First handle the weird escaped form in the example: /`/`/` ... /`/`/`
#     # We'll normalize any sequence of (/`){3} to ``` for easier handling.
#     text = re.sub(r'(/`){3}', '```', text)
#
#     # Convert triple-backtick fenced blocks. Capture optional language after the opening fence.
#     def repl_block(m):
#         fence_lang = m.group(1) or ''
#         body = m.group(2)
#         # Jira {code} macro optionally supports a language: {code:java}
#         lang = ''
#         if fence_lang:
#             # fence_lang may start with a newline or a language token; strip whitespace
#             fence_lang = fence_lang.strip()
#             # if it's just a newline, ignore
#             if fence_lang and fence_lang != '\n':
#                 # pull first token
#                 lang_token = fence_lang.split()[0]
#                 # sanitize token (letters/digits)
#                 if re.match(r'^[A-Za-z0-9#+-]+$', lang_token):
#                     lang = f':{lang_token}'
#         # Jira code macro wants newlines preserved; remove leading/trailing newlines from body
#         body = body.rstrip('\n')
#         return f'{{code{lang}}}\n{body}\n{{code}}'
#
#     # Pattern: opening ``` optionally followed by language (no newline), newline, body, closing ```
#     # We'll allow language on same line as opening fence or not.
#     block_pattern = re.compile(r'```([^\n`]*)\n(.*?)```', re.DOTALL)
#     text = block_pattern.sub(repl_block, text)
#
#     # Convert any remaining inline backtick code: `code` -> {code:inline=true}code{code}
#     # Jira doesn't have a true inline code macro, but {code:inline=true} works in some instances.
#     # If you prefer monospaced single ticks, use +code+ or {{code}}; we'll use {{code}} which Jira supports.
#     text = re.sub(r'`([^`]+)`', r'{{\1}}', text)
#
#     return text
#
# def convert_mentions(text: str) -> str:
#     # Convert @username occurrences. Slack may have <@U12345|name> form but your example uses @name.
#     # Handle plain @name
#     def repl(m):
#         return map_mention(m.group(0))
#     text = re.sub(r'@\w[\w.-]*', repl, text)
#     # Convert Slack full user-link form <@U12345|name> -> @name (or mapped)
#     text = re.sub(r'<@[^|>]+\|([^>]+)>', lambda m: map_mention('@' + m.group(1)), text)
#     return text
#
# def convert_lists(text: str) -> str:
#     # Slack numbered lists already look like "1. ..." which Jira accepts.
#     # Ensure there's a blank line before top-level lists to render correctly in Jira.
#     text = re.sub(r'(\S)\n([0-9]+\.)', r'\1\n\n\2', text)
#     return text
#
# def normalize_newlines(text: str) -> str:
#     # Collapse more than 2 consecutive blank lines to 2 (Jira displays extra spacing weirdly)
#     text = re.sub(r'\n{3,}', '\n\n', text)
#     # Trim leading/trailing whitespace
#     return text.strip() + '\n'
#
# def convert(text: str) -> str:
#     text = text.replace('\\n', '\n')  # convert escaped \n sequences into real newlines if present
#     text = convert_code_blocks(text)
#     text = convert_mentions(text)
#     text = convert_lists(text)
#     text = normalize_newlines(text)
#     return text
#
# def main(argv):
#     if len(argv) > 1:
#         with open(argv[1], 'r', encoding='utf-8') as f:
#             src = f.read()
#     else:
#         src = sys.stdin.read()
#
#     out = convert(src)
#     sys.stdout.write(out)
#
# if __name__ == '__main__':
#     main(sys.argv)
#
#
#import re
#import sys
#
#MENTION_MAP = {}
#
#def map_mention(token: str) -> str:
#    name = token.lstrip('@')
#    jira = MENTION_MAP.get(name)
#    return f'@{jira}' if jira else token
#
#def convert_code_blocks(text: str) -> str:
#    """
#    1) Normalizes escaped form (/`/`/`) to a consistent marker.
#    2) Converts fenced code blocks (```...```) to {code}...{code}.
#    3) Leaves remaining single backticks for inline code conversion later.
#    """
#    # 1) Normalize the escaped sequence /`/`/` to a placeholder fence token that won't collide with single backticks.
#    # Use a token unlikely to appear in normal text.
#    PLACEHOLDER = '<<<TRIPLE_BACKTICK_PLACEHOLDER>>>'
#    text = re.sub(r'(/`){3}', PLACEHOLDER, text)
#
#    # 2) Convert all fenced blocks. Handle both forms:
#    #    - placeholder followed immediately by optional lang and newline, or
#    #    - standard ```
#    # We'll support an optional language token after the fence.
#    def make_block_replacer(fence):
#        # fence is either '```' or PLACEHOLDER
#        pattern = re.compile(r'%s([^\n`]*)\n(.*?)%s' % (re.escape(fence), re.escape(fence)), re.DOTALL)
#        def repl(m):
#            fence_lang = (m.group(1) or '').strip()
#            body = m.group(2).rstrip('\n')
#            lang = ''
#            if fence_lang and re.match(r'^[A-Za-z0-9#+-]+$', fence_lang.split()[0]):
#                lang = ':' + fence_lang.split()[0]
#            return f'{{code{lang}}}\n{body}\n{{code}}'
#        return lambda s: pattern.sub(repl, s)
#
#    # Apply for both real triple backticks and placeholder
#    text = make_block_replacer(PLACEHOLDER)(text)
#    text = make_block_replacer('```')(text)
#
#    # 3) Remove any remaining placeholders left without a closing fence by converting the placeholder back
#    #    to literal triple backticks so they won't be treated as inline ticks.
#    text = text.replace(PLACEHOLDER, '```')
#
#    return text
#
#def convert_mentions(text: str) -> str:
#    text = re.sub(r'<@[^|>]+\|([^>]+)>', lambda m: map_mention('@' + m.group(1)), text)
#    text = re.sub(r'@\w[\w.-]*', lambda m: map_mention(m.group(0)), text)
#    return text
#
#def convert_inline_code(text: str) -> str:
#    # Convert single-backtick inline code `...` to Jira inline code using double braces {{...}}.
#    # Only convert instances where there is a matching closing backtick on the same line.
#    return re.sub(r'`([^`\n]+)`', r'{{\1}}', text)
#
#def normalize_newlines(text: str) -> str:
#    text = re.sub(r'\n{3,}', '\n\n', text)
#    return text.strip() + '\n'
#
#def convert(text: str) -> str:
#    text = text.replace('\\n', '\n')
#    text = convert_code_blocks(text)   # handle fenced blocks first
#    text = convert_mentions(text)
#    text = convert_inline_code(text)   # then inline code
#    text = normalize_newlines(text)
#    return text
#
#def main(argv):
#    if len(argv) > 1:
#        with open(argv[1], 'r', encoding='utf-8') as f:
#            src = f.read()
#    else:
#        src = sys.stdin.read()
#    sys.stdout.write(convert(src))
#
#if __name__ == '__main__':
#    main(sys.argv)
#
#
#
#"""
#slack_to_jira.py - robust conversion from Slack-like markup to Jira formatted text.
#
#Key behaviors:
#- Treats both ``` and the escaped form /`/`/` as fenced code blocks, but only when the
#  opening fence is on its own line (optionally with a language token) and the closing fence
#  is on its own line. This prevents footnote markers like "[0]" from being captured.
#- Converts fenced blocks to {code[:lang]} ... {code}.
#- Converts inline `code` to {{code}} (only if on same line).
#- Preserves URLs, mentions, and blank lines.
#"""
#
#import re
#import sys
#from typing import match
#
#mention_map = {
#    # e.g. 'shantanu': 'shantanu.jira'
#}
#
#def map_mention(token: str) -> str:
#    name = token.lstrip('@')
#    jira = mention_map.get(name)
#    return f'@{jira}' if jira else token
#
#def convert_mentions(text: str) -> str:
#    # convert <@u123|name> -> @name
#    text = re.sub(r'<@[^|>]+\|([^>]+)>', lambda m: map_mention('@' + m.group(1)), text)
#    # convert plain @name
#    text = re.sub(r'@\w[\w.-]*', lambda m: map_mention(m.group(0)), text)
#    return text
#
#def convert_fenced_code(text: str) -> str:
#    """
#    convert fenced code blocks where the opening fence is on its own line:
#      ```[lang]
#      code...
#      ```
#    also supports the escaped form where the message contains the literal characters /`/`/`
#    as the fence; treat that as an opening/closing fence only when it appears alone on its line.
#
#    approach:
#    - normalize the escaped sequence /`/`/` to a unique placeholder token on lines where it appears alone.
#    - use a regex that requires the opening fence to be the only non-space text on that line
#      (except optional lang tokens), then capture until a closing fence that is also on its own line.
#    - replace with jira {code[:lang]} ... {code} preserving the body exactly.
#    """
#
#    # placeholder unlikely to appear in real messages
#    placeholder = '<<<triple_bckt_placeholder_9f3b>>>'
#
#    # normalize lines that are exactly the escaped sequence possibly with whitespace.
#    # this avoids normalizing sequences that are embedded inline.
#    text = re.sub(r'^[ \t]*/`/`/`[ \t]*$(?m)', placeholder, text)
#
#    # also normalize literal ``` lines to a consistent marker for matching simplicity
#    text = re.sub(r'^[ \t]*```[ \t]*$(?m)', '```', text)
#
#    # regex to find fenced blocks where the opening fence marker (either ``` or placeholder)
#    # is on its own line optionally followed by a language token on the same line,
#    # then capture all following lines until a matching fence on its own line.
#    fence_pattern = re.compile(
#        r'^(?p<fence>(?:' + re.escape(placeholder) + r'|```))'        # fence marker at line start
#        r'[ \t]*(?p<lang>[a-za-z0-9#+-]*)[ \t]*\n'                   # optional language on same line, then newline
#        r'(?p<body>.*?)'                                             # non-greedy body
#        r'^[ \t]*' + re.escape('```') + r'[ \t]*$'                   # closing fence must be ``` on its own line
#        , re.multiline | re.dotall
#    )
#
#    def repl(m: match) -> str:
#        lang = m.group('lang') or ''
#        body = m.group('body').rstrip('\n')
#        lang_suffix = f':{lang}' if lang else ''
#        return f'{{code{lang_suffix}}}\n{body}\n{{code}}'
#
#    # note: we match closing fence as literal ``` for simplicity; if a placeholder was used
#    # for the opening fence, the closing fence in the source will usually also be the escaped form
#    # (which we normalized to the placeholder line). however, since we replaced escaped lines with the placeholder,
#    # we need to allow the placeholder as "opening" but require the closing fence to be either placeholder or ```.
#    # to handle both, run two passes: first with placeholder as opening and placeholder as closing,
#    # second with ``` opening and ``` closing. that avoids accidental cross-matching.
#    # first pass: placeholder ... placeholder
#    pattern_placeholder = re.compile(
#        r'^(?p<fence>' + re.escape(placeholder) + r')[ \t]*(?p<lang>[a-za-z0-9#+-]*)[ \t]*\n(?p<body>.*?)(?m)^[ \t]*' + re.escape(placeholder) + r'[ \t]*$',
#        re.multiline | re.dotall
#    )
#    text = pattern_placeholder.sub(repl, text)
#
#    # second pass: ``` ... ```
#    pattern_backtick = re.compile(
#        r'^(?p<fence>```)[ \t]*(?p<lang>[a-za-z0-9#+-]*)[ \t]*\n(?p<body>.*?)(?m)^[ \t]*```[ \t]*$',
#        re.multiline | re.dotall
#    )
#    text = pattern_backtick.sub(repl, text)
#
#    # any remaining placeholder lines that didn't form a matched pair should be turned back into literal ```
#    text = text.replace(placeholder, '```')
#
#    return text
#
#def convert_inline_code(text: str) -> str:
#    # convert inline `...` only when both backticks are on the same line (no newlines inside)
#    return re.sub(r'`([^`\n]+)`', r'{{\1}}', text)
#
#def normalize_newlines(text: str) -> str:
#    # collapse more than 2 blank lines to 2 to avoid excessive spacing
#    text = re.sub(r'\n{3,}', '\n\n', text)
#    return text.strip() + '\n'
#
#def convert(text: str) -> str:
#    # convert escaped literal '\n' sequences to real newlines if input used them
#    text = text.replace('\\n', '\n')
#
#    # 1) convert fenced code blocks first (requires fences on their own lines)
#    text = convert_fenced_code(text)
#
#    # 2) mentions
#    text = convert_mentions(text)
#
#    # 3) inline code
#    text = convert_inline_code(text)
#
#    # 4) normalize spacing
#    text = normalize_newlines(text)
#
#    return text
#
#def main(argv):
#    if len(argv) > 1:
#        with open(argv[1], 'r', encoding='utf-8') as f:
#            src = f.read()
#    else:
#        src = sys.stdin.read()
#
#    sys.stdout.write(convert(src))
#
#if __name__ == '__main__':
#    main(sys.argv)
#
#
#"""
#slack_to_jira.py
#
#Converts Slack-like markup to Jira formatted text.
#
#Handles:
#- Fenced code blocks using either:
#    - lines containing only ``` (optionally followed by a language token on the same line), or
#    - lines containing only /`/`/` (the escaped-backtick pattern).
#  Those blocks are converted to {code[:lang]} ... {code}.
#- Inline code `...` -> {{...}} (only on same line).
#- Preserves footnotes like [0], blank lines, URLs, and mentions.
#"""
#
#import re
#import sys
#from typing import Match
#
#def convert_fenced_blocks(text: str) -> str:
#    # Normalize windows CRLF
#    text = text.replace('\r\n', '\n')
#
#    # We'll temporarily replace any escaped-fence line "/`/`/`" (with optional surrounding spaces)
#    # with a unique token that won't be affected by later regexes. We only replace when it's alone on the line.
#    ESC_PLACE = '<<<ESCAPED_TRIPLE_FENCE>>>'
#
#    text = re.sub(r'^[ \t]*/`/`/`[ \t]*$(?m)', ESC_PLACE, text)
#
#    # Now define a function to replace any fenced block where the opening fence marker is on its own line,
#    # optionally followed by a language token on the same line. The closing fence must also be on its own line.
#    def replace_for(fence_marker: str, txt: str) -> str:
#        # fence_marker will be either ESC_PLACE or ```
#        # Build a regex that requires the opening marker to be at line start, optional lang, newline,
#        # then capture until a closing marker at line start.
#        pattern = re.compile(
#            r'^(?P<open>' + re.escape(fence_marker) + r')[ \t]*(?P<lang>[A-Za-z0-9#+-]*)[ \t]*\n'  # opening line
#            r'(?P<body>.*?)'                                                                        # body (non-greedy)
#            r'^[ \t]*' + re.escape(fence_marker if fence_marker == '```' else fence_marker) + r'[ \t]*$'  # closing marker
#            , re.MULTILINE | re.DOTALL
#        )
#
#        def repl(m: Match) -> str:
#            lang = m.group('lang') or ''
#            body = m.group('body').rstrip('\n')
#            lang_suffix = ':' + lang if lang else ''
#            return f'{{code{lang_suffix}}}\n{body}\n{{code}}'
#
#        return pattern.sub(repl, txt)
#
#    # First replace ESC_PLACE fenced blocks (those came from /`/`/` lines)
#    text = replace_for(ESC_PLACE, text)
#    # Then replace normal ``` fenced blocks
#    text = replace_for('```', text)
#
#    # Any remaining ESC_PLACE tokens that didn't have a closing fence (unmatched) should be turned back into literal /`/`/`
#    text = text.replace(ESC_PLACE, '/`/`/`')
#
#    return text
#
#def convert_inline_code(text: str) -> str:
#    # Convert inline `...` to {{...}} only when both backticks are on the same line.
#    return re.sub(r'`([^`\n]+)`', r'{{\1}}', text)
#
#def convert_mentions(text: str) -> str:
#    # Keep @name as-is (optionally map later). Handle Slack <@U123|name> -> @name
#    text = re.sub(r'<@[^|>]+\|([^>]+)>', r'@\1', text)
#    return text
#
#def normalize_newlines(text: str) -> str:
#    # Collapse 3+ newlines into 2; trim bounds
#    text = re.sub(r'\n{3,}', '\n\n', text)
#    return text.strip() + '\n'
#
#def convert(text: str) -> str:
#    # Convert escaped literal "\n" sequences into real newlines if present
#    text = text.replace('\\n', '\n')
#
#    # 1) Convert fenced code blocks first (requires fence lines alone)
#    text = convert_fenced_blocks(text)
#
#    # 2) Mentions
#    text = convert_mentions(text)
#
#    # 3) Inline code
#    text = convert_inline_code(text)
#
#    # 4) Normalize spacing
#    text = normalize_newlines(text)
#
#    return text
#
#def main(argv):
#    if len(argv) > 1:
#        with open(argv[1], 'r', encoding='utf-8') as f:
#            src = f.read()
#    else:
#        src = sys.stdin.read()
#    sys.stdout.write(convert(src))
#
#if __name__ == '__main__':
#    main(sys.argv)
#
#
#
import re
import sys


def slack_to_jira(text):
    result = text

    result = result.replace('\\n', '\n')
    result = result.replace('\\"', '"')
    result = re.sub(r'/`/`/`(.*?)/`/`/`', lambda m: '{code}\n' + m.group(1) + '\n{code}', result, flags=re.DOTALL)
    result = re.sub(r'```(.*?)```', lambda m: '{code}\n' + m.group(1) + '\n{code}', result, flags=re.DOTALL)
    result = re.sub(r'`([^`]+)`', r'{{\1}}', result)
    result = re.sub(r'\*\*\*(.+?)\*\*\*', r'*_\1_*', result)
    result = re.sub(r'\*\*(.+?)\*\*', r'*\1*', result)
    result = re.sub(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)', r'_\1_', result)
    result = re.sub(r'~~(.+?)~~', r'-\1-', result)
    result = re.sub(r'<([^|>]+)\|([^>]+)>', r'[\2|\1]', result)
    result = re.sub(r'<(https?://[^>]+)>', r'\1', result)
    result = re.sub(r'^>\s*(.*)$', r'bq. \1', result, flags=re.MULTILINE)
    result = re.sub(r'^•\s+(.*)$', r'* \1', result, flags=re.MULTILINE)
    result = re.sub(r'^\s*[-*]\s+(.*)$', r'* \1', result, flags=re.MULTILINE)
    result = re.sub(r'^\s*(\d+)\.\s+(.*)$', r'# \2', result, flags=re.MULTILINE)
    result = re.sub(r'<@([A-Z0-9]+)>', r'@\1', result)

    lines = result.split('\n')
    processed = []
    in_list = False

    for i, line in enumerate(lines):
        is_bullet = line.strip().startswith('*') and not line.strip().startswith('**')
        is_numbered = re.match(r'^\s*#\s+', line)
        is_list_item = is_bullet or is_numbered

        if is_list_item and not in_list:
            in_list = True
        elif not is_list_item and in_list:
            in_list = False
            if line.strip():
                processed.append('')

        processed.append(line)

    result = '\n'.join(processed)

    return result


def main():
    if len(sys.argv) > 1:
        input_text = ' '.join(sys.argv[1:])
    else:
        input_text = sys.stdin.read()

    output = slack_to_jira(input_text)
    print(output)


if __name__ == '__main__':
    main()
