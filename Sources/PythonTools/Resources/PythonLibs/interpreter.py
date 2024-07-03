#
#  code_completion.py
#
#
#  Created by Tibor Felföldy on 2024-07-01.
#

import sys
import json
import rlcompleter
import builtins

def completions(code: str) -> list[str]:
    # Retrieve the globals dictionary from the __main__ module
    main_module = builtins.__import__("__main__")
    globals = main_module.__dict__
    
    completer = rlcompleter.Completer(globals)
    
    completion_list = []
    state = 0
    
    # Get completions until no more are found
    while True:
        completion = completer.complete(code, state)
        if completion is None:
            break
        completion_list.append(completion)
        state += 1
    
    return completion_list
