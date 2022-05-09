```
Generate a list of possible words based on wordles letter feedback

Usage: 
    wordle <absent> <correct> <present>
    wordle [-a|--absent] <absent> [-c|--correct] <correct> [-p|--present] <present>

Options:
    -a, --absent        List all letters that are not in the word
                        Example: qrdops
    -c, --correct       Define which letters are known on which position
                        Example: a=3 r=5
                        A is in the word on position 3
                        R is in the word on position 5
    -h, --help          Show help
    -l, --letters       List all available letters. Has priority over --absent 
    -p, --present       Define which letters are in the word but are not in the
                        given position(s).
                        Example: a=3,4 r=5
                        A is in the word but not on position 3 and 4
                        R is in the word but not on position 5
    -f, --frequency     Show letter count
```
