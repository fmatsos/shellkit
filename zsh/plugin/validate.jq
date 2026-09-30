# Checks a plugin.json against schema.json, with jq only (shkit runs it; a plugin
# repository can too, e.g. in its CI): one error per line, none = valid.
#   jq -r --slurpfile schema schema.json -f validate.jq plugin.json
# Keywords read: type, required, anyOf (of required), properties,
# additionalProperties: false, items, minItems, minLength, pattern. Others are ignored.
def check($s; $p):
  . as $v | ($v | type) as $t
  | (if $s.type and $s.type != $t then "\($p): \($s.type) expected" else empty end),
    (if $t == "object" then
       (($s.required // [])[] | select(. as $k | $v | has($k) | not) | "\($p): \(.) is required"),
       (if $s.anyOf and ([$s.anyOf[].required | all(.[]; . as $k | $v | has($k))] | any | not)
        then "\($p): one of \([$s.anyOf[].required[]] | join(", ")) is required" else empty end),
       ($v | keys[] as $k
        | if ($s.properties // {}) | has($k) then $v[$k] | check($s.properties[$k]; "\($p).\($k)")
          elif $s.additionalProperties == false then "\($p).\($k): unknown key"
          else empty end)
     elif $t == "array" then
       (if $s.minItems and ($v | length) < $s.minItems then "\($p): at least \($s.minItems) item(s)" else empty end),
       (if $s.items then range($v | length) as $i | $v[$i] | check($s.items; "\($p)[\($i)]") else empty end)
     elif $t == "string" then
       (if $s.minLength and ($v | length) < $s.minLength then "\($p): empty" else empty end),
       (if $s.pattern and ($v | test($s.pattern) | not) then "\($p): \($v | tojson) must match \($s.pattern)" else empty end)
     else empty end);
check($schema[0]; "plugin.json")
