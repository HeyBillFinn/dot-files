. ~/.virtualenvs/venv/bin/activate
now_watch()
{
    echo "Running $PERSISTENT_HISTORY_LAST"
    command=$PERSISTENT_HISTORY_LAST
    patterns=""
    for var in "$@"
    do
        patterns="$patterns;*.$var"
    done
    watchmedo shell-command --patterns="$patterns" --recursive --command="echo Running...; $command"
}

