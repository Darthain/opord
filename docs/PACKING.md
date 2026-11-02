# Packing ARTIC AI v0.3.11-alpha

Pack `source/artic_ai_core` as `artic_ai_core.pbo`, then place the PBO in `@ARTIC_AI/addons/`.

For the current development tests, an unbinarized PBO is valid and has proven reliable with the installed Arma 3 Addon Builder.

If using Binarize, verify that Addon Builder actually copies the SQF tree. The finished PBO must contain both the config and `functions/.../*.sqf`. A PBO containing only `config.bin` / `config.cpp` will load the function declarations but fail at runtime with `fn_preInit.sqf not found`.

Recommended Addon Builder source:

```text
P:\ARTIC_AI_v0.3.11-alpha\source\artic_ai_core
```

Addon prefix:

```text
artic_ai_core
```

For testing, if a binarized pack again drops the SQF files, turn Binarize off and pack the full source tree rather than testing an incomplete PBO.
