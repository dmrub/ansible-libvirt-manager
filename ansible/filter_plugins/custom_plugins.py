from __future__ import print_function
import sys
from jinja2 import Environment, contextfilter, Template
from markupsafe import Markup

def port_range(values, count):
    icount = int(count)
    result = []
    for value in values:
        start = int(value)
        result.append("%d-%d" % (start, start+icount))
    return result

def jinja2_env(*args, **kwargs):
    return Environment(*args, **kwargs)

@contextfilter
def render(context, value, envoptions=None, **vars):
    #print("VALUE: %s OPTIONS %s CONTEXT %s VARS %s" % (value, envoptions, context.keys(), context.vars.keys()), file=sys.stderr)
    if envoptions is None:
        envoptions = {}
    env = Environment(**envoptions)
    tmpl = env.from_string(value)
    if not vars:
        v = context
    else:
        v = {}
        v.update(context)
        v.update(vars)
    result = tmpl.render(v)
    #result = Template(value).render(context)
    if context.eval_ctx.autoescape:
        result = Markup(result)
    return result

class FilterModule(object):
    ''' Custom filters are loaded by FilterModule objects '''

    def filters(self):
        ''' FilterModule objects return a dict mapping filter names to
            filter functions. '''
        return {
            'port_range': port_range,
            'render': render,
            'jinja2_env': jinja2_env
        }
