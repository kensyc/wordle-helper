#!/usr/bin/bash

pacman -Q aspell aspell-en &> /dev/null

if [ $? -eq 1 ]; then
    echo "Aspell is not installed"
    exit 1
fi

set -e

declare -l letters
declare -a options
declare -a answers

for arg in "${@}"; do
    if [[ $arg == *.* ]]; then
        options+=($arg)
    elif [[ $arg =~ ^[a-zA-Z]+$ ]]; then
        if [[ ! -z $letters ]]; then
            echo "Multiple letter arguments found"
            exit 1
        fi
        # | tr '[:upper:]' '[:lower:]' todo: automatically put in lowercase
        letters=$arg
    else
        echo "Invalid argument found"
        echo $arg
        exit 1
    fi
done

# validate if all options have the same amount of dots
# validate if options or letters isn't empty

doesWordExist() {
    local word="$1"
    local x=$(echo $2 | sed 's/./& /g')

    # or use ${@:2} to get all arguments except the first one
    # i used shift to remove the first argument
    #shift

    for z in $x; do
        word="${word/./"$z"}"
    done

    #wordExists=$(curl -o /dev/null -I -s -w "%{http_code}\n" "https://api.dictionaryapi.dev/api/v2/entries/en/$word")
    #if [ $wordExists -eq 200 ]; then
    #    echo $word
    #fi
    touch file.txt
    echo "$word" >> file.txt
    wordExists=$(aspell list < file.txt)
    rm file.txt

    if [ -z "$wordExists" ]; then
        answers+=($word)
    fi
}

permutations=""
missing=${options[0]//[^.]}
missing=${#missing}

permutations=$(echo $letters | sed 's/./& /g')

for ((miss=1;miss<$missing;miss++)); do
    newPermutations=()

    for perm in ${permutations[@]}; do
        for ((i=0;i<${#letters};i++)); do
#            if [[ "${perm[*]}" =~ "${letters:i:1}" ]]; then
#                continue
#            fi
            newPermutations+=("$perm${letters:i:1}")
        done
    done

    permutations=${newPermutations[@]}
done

for permutation in ${permutations[@]}; do
    for word in ${options[@]}; do
        doesWordExist $word $permutation
    done
done

declare -A letterCounters
declare -a result

for letter in {a..z}; do
    letterCounters[$letter]=0
done

for word in ${answers[@]}; do
    uniqueLetters=()
    for ((i=0;i<${#word};i++)); do
        if [[ "${uniqueLetters[*]}" =~ "${word:i:1}" ]]; then
            continue
        fi
        uniqueLetters+=("${word:i:1}")
        ((letterCounters[${word:i:1}]+=1))
    done
done

knownLetters=$(echo ${options[1]} | sed 's/\.//g')
for count in ${!letterCounters[@]}; do
    if [[ ${letterCounters[$count]} -eq 0 || "${knownLetters[*]}" =~ "${count}" ]]; then
        continue
    fi
    result+=("${letterCounters[$count]}: $count")
done

IFS=$'\n' sorted=($(sort -rn <<<"${result[*]}"))
unset IFS

for answer in ${answers[@]}; do
    echo $answer
done

printf "%s\n" "${sorted[@]}"
