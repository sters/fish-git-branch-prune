function _git-branch-prune_default-read
    read -p 'echo "$argv[1] (default: $argv[2]):"' -l value
    if [ "$value" = '' ]
        set value $argv[2]
    end
    echo $value
end

function _git-branch-prune_simple-confirm
    set confirm (_git-branch-prune_default-read "$argv[1] Y or N" "n")
    if [ "$confirm" = "n" ] ;
        return 1
    end
    if [ "$confirm" = "N" ] ;
        return 1
    end
    return 0
end

function git-branch-prune --description 'Cleanup git branches'
    # check git repository
    git branch > /dev/null
    if [ $status -ne 0 ] ;
        echo "Here is not a git repository."
        return 1
    end

    set mainBranch (git branch -r | grep -v "\->" | cut -c3- | grep "^origin/master\$")
    if [ "$mainBranch" = "" ]
        set mainBranch (git branch -r | grep -v "\->" | cut -c3- | grep "^origin/main\$")
    end

    set mainBranch (_git-branch-prune_default-read "Set your remote main branch" "$mainBranch")

    # get branches
    set allLocalBranches (git for-each-ref refs/heads/ "--format=%(refname:short)")
    set targetBranches (git branch --merged | grep -vE 'master|develop|main' | grep -v '*' | cut -c3-)
    for branch in $allLocalBranches
        if contains $branch $targetBranches
            continue
        end
        if [ $branch = "master" ]
            continue
        end
        if [ $branch = "develop" ]
            continue
        end
        if [ $branch = "main" ]
            continue
        end

        set mergeBase (git merge-base $mainBranch $branch)
        set mergeDiffs (git cherry $mainBranch (git commit-tree (git rev-parse "$branch^{tree}") -p $mergeBase -m _))

        if string match -q "\-*" (echo $mergeDiffs | sed 's/-/\\\-/')
            set targetBranches $targetBranches $branch
        end
    end

    if [ "$targetBranches" = "" ] ;
        echo "Nothing to merged branch."
        return 1
    end

    # confirm
    echo -n "Remove these branches:"
    echo $targetBranches
    echo

    _git-branch-prune_simple-confirm "Delete OK?"
    if [ $status -ne 0 ] ;
        echo "Abort."
        return 1
    end
    echo

    # run
    for branche in $targetBranches
        git branch -D (echo $branche | tr -d ' ')
    end
end
