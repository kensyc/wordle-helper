#!/usr/bin/bash

which aspell &> /dev/null

if [ $? -eq 1 ]; then
    echo 'Aspell is not installed'
    exit 1
fi

set -e

usage() {
cat <<- EOF
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
    -h, --help          Help
    -l, --letters       List all available letters. Has priority over --absent 
    -p, --present       Define which letters are in the word but are not in the
                        given position(s).
                        Example: a=3,4 r=5
                        A is in the word but not on position 3 and 4
                        R is in the word but not on position 5
    -f, --frequency     Show letter count
EOF
}

# Remaining possible letters that can be used to find the word
declare -l letters

# Associative array of letters in the correct position. array[POSITION]="LETTER"
declare -A correct

# Associative array of letters but unknown position.
# array[LETTER]="WRONG_POSITION,WRONG_POSITION"
declare -A present

# A permutation is an allowed combination of a 5-letter word (based on
# remaining letters, letters in their correct position and letters that are not
# allowed on certain positions)
# The permutation is not necessarily a word. We'll use Aspell to filter out
# unexisting words
declare -a permutations

# Show letter frequency from answers
declare -i show_frequency=0

cleanup() {
    rm -f badwords
    rm -f allwords
}

#
# Convert present input to associative array
#
composePresentArray() {
    for letter in $@; do
        IFS='='
        read -ra temp <<< "$letter"

        present[${temp[0]}]=${temp[1]}
    done
    unset IFS
}

#
# Convert present input to associative array
#
composeCorrectArray() {
    for letter in $@; do
        IFS='='
        read -ra temp <<< "$letter"

        correct[${temp[1]}]=${temp[0]}
    done
    unset IFS
}

getRemainingLetters() {
    # -l | --letters has priority over --absent
    if [[ ! -z $letters ]]; then
        return
    fi

    local absent=$(echo $1 | sed "s/./&\\\|/g")
    letters="abcdefghijklmnopqrstuvwxyz"
    letters=$(echo $letters | sed "s/$absent//g")
}

initPermutations() {
    #
    # Fill start of the word as much as possible
    # i.e. if we already know the first 2 positions,
    # permutations will start with "xx" as start value
    #
    permutations=()
    for ((i=1;i<=5;i++)); do
        if [[ -z ${correct[$i]} ]]; then
            break
        fi

        permutations+=${correct[$i]}
    done

    #
    # permutations will be empty if we dont know first position
    # fill permutation array with all possible letters for the first position
    #
    if [[ ${#permutations[@]} -eq 0 ]]; then
        #
        # Split permutation string by space
        # The start array contains the first letter of each permutation
        #
        permutations=($(echo $letters | sed 's/./& /g'))

        # Clean the array of letters that are not allowed to be in the 1st position
        for p in ${permutations[@]}; do
            if [[ ${present[$p]} -eq 1 ]]; then
                permutations=(${permutations[@]/$p})
            fi
        done
    fi
}

generatePermutations() {
    # string of letters that are in the word
    known_letters_pattern="${correct[*]}${!present[*]}"
    known_letters_pattern=${known_letters_pattern//[, ]/}

    # number of letters we know
    local count_known_letters=$((${#present[@]}+${#correct[@]}))

    for ((position=$((${#permutations[0]}+1));position<=5;position++)); do
        tmp=()
        positions_remaining=$((6-position))

        for perm in ${permutations[@]}; do
            # detect if we already know current position and if so, add the
            # correct letter to the permutation
            if [[ ! -z ${correct[$position]} ]]; then
                tmp+=("$perm${correct[$position]}")
                continue
            fi

            # detect if there are known letters in $perm
            perm_known_letters=""
            for ((i=0;i<${#perm};i++)); do
                # is current perm letter a known letter
                if [[ $known_letters_pattern == *${perm:$i:1}* ]]; then
                    # check current known letter is a correct letter
                    if [[ ${correct[*]} =~ ${perm:$i:1} ]]; then
                        # check if the correct letter is in its correct position
                        # we should not count a letter if its a correct letter
                        # but not in its correct position
                        if [[ ${correct[$((i+1))]} == ${perm:$i:1} ]]; then
                            # avoid duplicates in perm_known_letters
                            if [[ $perm_known_letters != *${perm:$i:1}* ]];then
                                perm_known_letters="$perm_known_letters${perm:$i:1}"
                            fi
                        fi
                    else
                        # avoid duplicates in perm_known_letters
                        if [[ $perm_known_letters != *${perm:$i:1}* ]];then
                            perm_known_letters="$perm_known_letters${perm:$i:1}"
                        fi
                    fi
                fi
            done

            # make sure $perm has enough positions left to add known letters
            if [[ $(($positions_remaining+${#perm_known_letters})) -eq $count_known_letters ]]; then
                # at this point, only known letters are allowed to be added
                # get known letters that are missing from perm
                add=${!present[*]}
                add=${add//[$perm_known_letters]}

                # only add letters which are not yet present from the present array
                for ltr in ${add[@]}; do
                    # skip if letter is not allowed in this position
                    if [[ "${present[$ltr]}" == *$position* ]]; then
                        continue
                    fi
                    tmp+=("$perm$ltr")
                done

                continue
            fi

            for ((i=0;i<${#letters};i++)); do
                # skip if letter is not allowed in this position
                if [[ "${present[${letters:i:1}]}" == *$position* ]]; then
                    continue
                fi

                tmp+=("$perm${letters:i:1}")
            done
        done

        permutations=()
        permutations=${tmp[@]}
    done
}

countLetterFrequency() {
    local -A letter_counters

    # init array with counter per letter
    for letter in {a..z}; do
        letter_counters[$letter]=0
    done

    # count each letter
    for word in ${valid_words[@]}; do
        unique_letters=()

        for ((i=0;i<${#word};i++)); do
            letter=${word:i:1}

            # skip duplicates or known letters
            if [[ "${unique_letters[*]}" =~ "$letter" ]] || \
                [[ "${known_letters_pattern[*]}" =~ "$letter" ]]; then
                            continue
            fi

            unique_letters+=("$letter")
            ((letter_counters[$letter]+=1))
        done
    done

    for letter in ${!letter_counters[@]}; do
        if [[ ${letter_counters[$letter]} -eq 0 ]]; then
            continue
        fi
        echo "$letter: ${letter_counters[$letter]}"
    done |
    sort -rn -k2
}

argument_counter=0
while [ "$1" != "" ]; do
    case $1 in
        -a | --absent )
            shift
            getRemainingLetters $1
            ;;
        -c | --correct )
            shift
            composeCorrectArray $1
            ;;
        -l | --letters )
            shift
            letters=$1
            ;;
        -p | --present )
            shift
            composePresentArray $1 
            ;;
        -h | --help )
            usage
            exit
            ;;
        -f | --frequency )
            show_frequency=1
            ;;
        * )
            if [[ $argument_counter -eq 0 ]] && [[ $1 =~ [a-zA-Z] ]]; then
                getRemainingLetters $1
            elif [[ $argument_counter -eq 1 ]] && [[ $1 == *=* ]]; then
                composeCorrectArray $1
            elif [[ $argument_counter -eq 2 ]] && [[ $1 == *=* ]]; then
                composePresentArray $1 
            else
                usage
                exit 1
            fi
            ;;
    esac
    shift

    ((argument_counter=argument_counter+1))
done

initPermutations
generatePermutations

trap cleanup EXIT
echo ${permutations[*]} > allwords
echo $(aspell list < allwords) > badwords

# used perl here because muchos fasteros
# filter out badwords in allwords so we're left with only valid words
valid_words=$(perl -lpe 'open(A, "badwords"); @k = split(" ", <A>); for $w (@k) { s/$w//g }' allwords)

for answer in ${valid_words[@]}; do
    echo "${answer}"
done

if [[ show_frequency -eq 1 ]]; then
    countLetterFrequency
fi

cleanup
