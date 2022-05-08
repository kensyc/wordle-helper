#!/usr/bin/bash

set -e

pacman -Q aspell aspell-en &> /dev/null

if [ $? -eq 1 ]; then
    echo 'Aspell is not installed'
    exit 1
fi

# todo: add errorhandler to remove tmp files

declare -l letters
declare -l row
declare -a inputExcludes
declare -a permutations
declare -A excludes
declare -A includes
declare -a answers

usage() {
    echo "goddamnit"
}

argumentCounter=0
while [ "$1" != "" ]; do
    case $1 in
        -l | --letters )
            shift
            letters=$1
            ;;
        -r | --row )
            shift
            row="$1"
            ;;
        -e | --excludes )
            shift
            inputExcludes=($1)
            ;;
        -h | --help )
            usage
            exit
            ;;
        * )
            if [[ $argumentCounter -eq 0 ]]; then
                letters=$1
            elif [[ $argumentCounter -eq 1 ]]; then
                row="$1"
            elif [[ $argumentCounter -eq 2 ]]; then
                inputExcludes=($1)
            else
                usage
                exit 1
            fi
            ;;
    esac
    shift

    ((argumentCounter=argumentCounter+1))
done

#
# Convert excludes to associative array
#
for excl in ${inputExcludes[@]}; do
    IFS='='
    read -ra temp <<< "$excl"

    excludes[${temp[0]}]=${temp[1]}
done
unset IFS

#
# Get valid letter positions in associative array
#
for ((i=0;i<${#row};i++)); do
    if [[ ${row:i:1} != "." ]]; then
        includes[$((i+1))]=${row:i:1}
    fi
done

permutations=($(echo $row | grep -o '^[a-z]*'))
if [[ ${#permutations[@]} -eq 0 ]]; then
    #
    # Split permutation string by space
    # The start array contains the first letter of each permutation
    # Clean the array of letters that cannot be in the 1st position
    #
    permutations=($(echo $letters | sed 's/./& /g'))

    for p in ${permutations[@]}; do
        if [[ ${excludes[$p]} == *1* ]]; then
            permutations=${permutations[@]/$p}
        fi
    done
fi

# 1 problems: 
# if a letter is not allowed on multiple places, no worky

pattern="[^${includes[*]}${!excludes[*]}]"
pattern=${pattern//[, ]/}
currentKnownLetters=$((${#excludes[@]}+${#includes[@]}))

characterCount=$((${#permutations[0]}+1))
for ((position=$characterCount;position<=5;position++)); do
    newPermutations=()

    amountOfLettersLeft=$((6-position))

    for perm in ${permutations[@]}; do
        if [[ -v "includes[$characterCount]" ]]; then
            newPermutations+=("$perm${includes[$characterCount]}")
            continue
        fi

        knownLetters=${perm//$pattern}
        # todo: make dis faster
        knownLetters=$(echo $knownLetters | fold -w1 | uniq)
        knownLetters=$(echo $knownLetters | sed 's/ //g')
        countKnownLetters=${#knownLetters}

        if [[ $(($amountOfLettersLeft+$countKnownLetters)) -eq $currentKnownLetters ]]; then
            # at this point, only known letters is allowed to be added

            add=${!excludes[*]}
            add=${add//[$knownLetters]}

            # only add letters which are not yet present from the excludes
            for ltr in ${add[@]}; do
                if [[ "${excludes[$ltr]}" == *$characterCount* ]]; then
                    continue
                fi
                newPermutations+=("$perm$ltr")
            done

            continue
        fi

        for ((i=0;i<${#letters};i++)); do
            # check if letter is allowed to be in this position, if not, skip this permutation
            if [[ "${excludes[${letters:i:1}]}" == *$characterCount* ]]; then
                continue
            fi
            
            newPermutations+=("$perm${letters:i:1}")
        done
    done

    permutations=()
    permutations=${newPermutations[@]}
    ((characterCount++))
done

echo ${permutations[*]} > allwords
echo $(aspell list < allwords) > badwords

# used perl here because muchos fasteros
validwords=$(perl -lpe 'open(A, "badwords"); @k = split(" ", <A>); for $w (@k) { s/$w//g }' allwords)

declare -A letterCounters
declare -a result

for letter in {a..z}; do
    letterCounters[$letter]=0
done

for word in ${validwords[@]}; do
    uniqueLetters=()
    for ((i=0;i<${#word};i++)); do
        if [[ "${uniqueLetters[*]}" =~ "${word:i:1}" ]]; then
            continue
        fi
        uniqueLetters+=("${word:i:1}")
        ((letterCounters[${word:i:1}]+=1))
    done
done

knownLetters=("${includes[*]}${!excludes[*]}")
for count in ${!letterCounters[@]}; do
    if [[ ${letterCounters[$count]} -eq 0 || "${knownLetters[*]}" =~ "${count}" ]]; then
        continue
    fi
    result+=("${letterCounters[$count]}: $count")
done

IFS=$'\n' sorted=($(sort -rn <<<"${result[*]}"))
unset IFS

for answer in ${validwords[@]}; do
    echo $answer
done

printf "%s\n" "${sorted[@]}"
