!DLM COMMAND 1.0.0
debug,d : enable debug output
help,h  : display this help message

CMD prepare <?fodase> <fodase2> <fodase3> (
    model,m  <string {./arquivo_ner_train.iob}> : the model file to use as input             
    output,o <string {./datasets}>              : the directory to output the generated files
)

CMD init (
    output,o <string {./config}> : the path to output the generated config
)

CMD train (
    config,c <string {./config.cfg}> : the config file to use (train command only)
)
