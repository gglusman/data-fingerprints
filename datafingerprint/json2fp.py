# -----------------------------------------------------------------------------
# json2fp.py
# read json file and generate data fingerprint vectors (for length L)
# matching Gustavo's version 181214
#
# by Jewel Lee (jewel.lee@systemsbiology.org), last updated: 3/8/19
#
# Not included here:
# 1. skip_nulls (default is skipping null values)
# 2. excluded keys
# 3. multiple fingerprints (for prime number series)
# 4. modifications in newer versions
#
# naming conventions:
# https://www.python.org/dev/peps/pep-0008/#prescriptive-naming-conventions
# -----------------------------------------------------------------------------
import click
import os
import sys
import glob
import json
import math
import numpy as np
from functools import lru_cache

class DataFingerprint(object):
    def __init__(self, **kwargs):
        self.L = kwargs['length'] if 'length' in kwargs and kwargs['length'] is not None else 13
        self.norm = kwargs['norm'] if 'norm' in kwargs and kwargs['norm'] is not None else 0
        self.debug = kwargs['debug'] if 'debug' in kwargs and kwargs['debug'] is not None else 1
        self.tripler = False
        if 'tripler' in kwargs and kwargs['tripler'] is not None:
            self.tripler = True
        self.file_paths = kwargs['file_paths'] if 'file_paths' in kwargs and kwargs['file_paths'] is not None else None
        self.root = 'root'
        self.numeric_encoding = 'ME'    # ME, ML, smooth, simple [default]
        self.string_encoding = 'decay'  # decay, pair_sum
        self.string_encoding_decay = 0.1
        self.decimal = 3
        self.skip_nulls = True
        self.array_are_sets = False
        self.fp = np.zeros(self.L)
        self.statements = 0
        self.triples = []
        self.errors = []

    # -------------------------------------------------------------------------
    # reset
    #
    # -------------------------------------------------------------------------
    def reset(self):
        if self.debug > 1:
            print("#resetFingerprint()\n")
        self.fp = np.zeros(self.L)
        self.statements = 0
        self.triples = []
    #
    # # -------------------------------------------------------------------------
    # # set_length
    # #
    # # -------------------------------------------------------------------------
    # def set_length(self, Ls=None):
    #     if not Ls: Ls = self.L
    #     if self.debug: print("#setLs(%d)") % Ls
    #     assert isinstance(Ls, int) and Ls > 1, "Wrong fingerprint length"

    # -------------------------------------------------------------------------
    # isnumeric
    # return true if the string is numeric value (float or int) and not NAN
    #
    # -------------------------------------------------------------------------
    @staticmethod
    def isnumeric(n):
        if isinstance(n, float):
            return True
        if isinstance(n, int):
            return True
        if isinstance(n, str):
            from re import fullmatch
            return bool(fullmatch(r'[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?', str(n)))
        return False

    # -------------------------------------------------------------------------
    # frexp10
    # return mantissa and exponent in base 10 (np.frexp & math.frexp are base 2)
    # -------------------------------------------------------------------------
    @staticmethod
    def frexp10(n):
        if n == 0:
            return 0.0, 0
        else:
            e = int(math.log10(abs(n)))
            m = n/10**e
            return m, e

    # -------------------------------------------------------------------------
    # vector_value
    # compute the value of the first argument in vector form
    # -------------------------------------------------------------------------
    @lru_cache(maxsize=None)
    def vector_value(self, o):
        length = self.L
        if self.debug > 2:
            print("\n#computing vector_value:\t%s" % str(o))
        new = np.zeros(length)
        if not o:
            return new

        # for NUMBERS encoding
        if self.isnumeric(o):
            if isinstance(o, str):
                o = float(o)
            # if it's null value zero
            if not o:
                return new
            # -----------------------------------------------------------------
            # number method #1: ME (Mantissa/Exponent)
            elif self.numeric_encoding == "ME":
                mantissa, exponent = self.frexp10(o)
                # encode mantissa - a fraction in range (-1~1)
                mantissa *= (length / 10.0)  # make mantissa in the range of -L to L
                over = abs(mantissa - int(mantissa))
                if over > np.finfo(float).eps:
                    new[int(mantissa % length)] += (1 - over)
                    index = mantissa + 1 if mantissa > 0 else mantissa - 1
                    new[int(index % length)] += over
                else: # in what case it will come to here?
                    new[int(mantissa % length)] += 1
                # encode the exponent - an integer, which can be negative
                new[int(exponent % length)] += 1
            # -----------------------------------------------------------------
            # number method #2: ML (Mantissa/Log value)
            elif self.numeric_encoding == "ML":
                mantissa, exponent = self.frexp10(o)
                # encode mantissa - a fraction in range (-1~1)
                mantissa *= (length / 10.0)
                over = np.abs(mantissa - int(mantissa))
                if over > np.finfo(float).eps:
                    new[int(mantissa % length)] += (1 - over)
                    index = mantissa + 1 if mantissa > 0 else mantissa - 1
                    new[int(index % length)] += over
                else:
                    new[int(mantissa % length)] += 1

                # encode the log absolute value - which can be negative
                if o > 0:
                    logvalue = np.log(abs(o))
                    over = abs(logvalue-int(logvalue))
                    if over > np.finfo(float).eps:
                        new[int(logvalue % length)] += (1 - over)
                        index = logvalue + 1 if logvalue > 0 else logvalue - 1
                        new[int(index % length)] += over
                    else:
                        new[int(logvalue % length)] += 1
            # -----------------------------------------------------------------
            # number method #3: Smooth
            elif self.numeric_encoding == "smooth":
                over = o - int(o)
                new[int(o % length)] += (1 - over)
                new[int((o+1) % length)] += over
            else:
                new[int(o % length)] += 1
        else:
            # -----------------------------------------------------------------
            # string method #1: DECAY
            if self.string_encoding == "decay":
                decay = self.string_encoding_decay if self.string_encoding_decay else 0.1
                remain = (1 - decay)
                v = ord(o[0])
                new[int(v % length)] += 1
                for i in range(1, len(o)):
                    v = v*remain + ord(o[i])*decay
                    if self.debug > 5:
                        print("#decay: %s %d %d %.4f" % (o, i, ord(o[i]), v))
                    sv = v*length/10.0
                    over = sv - int(sv)    # beware of the rounding error here
                    new[int(sv % length)] += (1-over)
                    new[int((sv+1) % length)] += over
            # -----------------------------------------------------------------
            # string method #2: PAIR SUM
            elif self.string_encoding == "pair_sum":
                new[int(ord(o[0]) % length)] += 1
                for i in range(1, len(o)):
                    v = ord(o[i]) + ord(o[i-1])
                    new[int(v % length)] += 1

        if self.debug > 2:
            fp_string = '\t'.join(str(round(i, self.decimal)) for i in new)
            print("#prelim:\t" + fp_string + "\t sum: %.3f" % sum(new))

        # normalize to a unit vector (sum of 1)
        new = np.array(new) - min(new)
        if sum(new) != 0:
            new = np.array(new) / sum(new)
        if self.debug > 2:
            fp_string = '\t'.join(str(round(i, self.decimal)) for i in new)
            print("#final: \t" + fp_string + "\t sum: %.3f" % sum(new))
        return new


    # -------------------------------------------------------------------------
    # add_vector_value
    #
    # -------------------------------------------------------------------------
    def add_vector_value(self, v1, v2, v3, stuff=None):
        length = self.L
        fp = self.fp
        if self.debug > 2:
            print("\n#adding vector values:\t%s" % str(stuff))
        for i in range(length):
            v = (v1[i] + v2[int((i+1) % length)] + v3[int((i+2) % length)])/3
            fp[i] += v
        if self.debug > 2:
            fp_string = '\t'.join(str(round(i, self.decimal)) for i in fp)
            print("#result:\t" + fp_string)

    # -------------------------------------------------------------------------
    # recurseStructure
    #
    # -------------------------------------------------------------------------
    def recurse_structure(self, obj, name=None, base=None):
        if self.debug > 1:
            print("\n#recursing:\t%s" % str(type(obj)))
        length = self.L
        if name is None: name = 'root'
        if base is None: base = self.vector_value(0)
        # -------------------------------------------------------------------------
        # TYPE 1 data: python dictionary, perl hashes
        if isinstance(obj, dict):
            keys_used = 0
            for key, cargo in obj.items():
                # skip empty strings, null value, careful about integer "0"
                if cargo or isinstance(cargo, int):
                    vkey = self.vector_value(key)
                    if isinstance(cargo, (list, dict)):
                        # if it's another list or dict, cargo is the keys_used (length)
                        cargo = self.recurse_structure(cargo, key, vkey)
                    self.add_vector_value(base, vkey, self.vector_value(cargo),
                                            ("#hash_entry", name, key, cargo))
                    self.triples.append(list([name, key, cargo]))
                    keys_used += 1   # number of statements used in generating this vector
            self.statements += keys_used
            return keys_used
        # -------------------------------------------------------------------------
        # TYPE 2 data: python list, perl arrays
        elif isinstance(obj, list):
            if len(obj) == 1:
                # structure has an extra layer, recurse its content directly
                if isinstance(obj[0], (list, dict)):
                    return self.recurse_structure(obj[0], name, base)
                else:
                    # key-value pair has an extra layer, retrieve key-value
                    return obj[0]
            if self.array_are_sets:
                keys_used = 0
                for key in range(len(obj)):
                    cargo = obj[key]
                    vkey = self.vector_value(0)     # all positions in array get the same key
                    if cargo or isinstance(cargo, int):
                        if isinstance(cargo, (list, dict)):
                            cargo = self.recurse_structure(cargo, key, vkey)
                        self.add_vector_value(base, vkey, self.vector_value(cargo),
                                          ("set_entry", name, key, cargo))
                        self.triples.append(list([name, key, cargo]))
                        keys_used += 1
                self.statements += keys_used
                # return self.vector_value(keys_used) # verion 180913
                return keys_used # in newer version 181214
            else:
                for i in range(len(obj)):
                    obj[i] = self.recurse_structure(obj[i], i, self.vector_value(i))
                # add link to first element in array
                self.add_vector_value(base, self.vector_value(0), self.vector_value(obj[0]),
                                            ("#array_start", name, 0, obj[0]))
                self.triples.append(list([name, 0, obj[0]]))
                # add links between subsequent pairs of elements in array
                for j in range(1, len(obj)):
                    self.add_vector_value(base, self.vector_value(obj[j-1]), self.vector_value(obj[j]),
                                            ("#array_pair", name, obj[j-1], obj[j]))
                    self.triples.append(list([name, obj[j-1], obj[j]]))
                # add link from last element in array
                self.add_vector_value(base, self.vector_value(obj[len(obj)-1]), self.vector_value(len(obj)),
                                            ("#array_end", name, obj[len(obj)-1], len(obj)))
                self.triples.append(list([name, obj[len(obj)-1], len(obj)]))
                self.statements += (len(obj)+1)
                return len(obj)
        else:
            return obj

    # -----------------------------------------------------------------------------
    # normalize
    #
    # Normalize the fingerprint by subtracting the mean and dividing by the
    # standard deviation
    # -----------------------------------------------------------------------------
    def normalize(self):
        if self.debug > 0:
            print("\n#normalize():" )
        fp = self.fp
        return (np.array(fp)-np.mean(fp)) / np.std(fp)

    # -----------------------------------------------------------------------------
    # reformat
    #
    # -----------------------------------------------------------------------------
    @staticmethod
    def reformat(value):
        if isinstance(value, int):
            value = str(value)
        else:
            value = '"{}"'.format(value)
        return value

    # -----------------------------------------------------------------------------
    # write_triple
    # A triple is name, key, cargo
    # Ex:
    # JSON input is:
    # {
    #     "name": {
    #         "first": "John",
    #         "last": "Smith"
    #     },
    #     "children": [
    #         "Adam",
    #         "Beth",
    #         "Chloe"
    #     ]
    # }
    #
    # Triple output is:
    # "name" "first" "John"
    # "name" "last"  "Smith"
    # "root" "name"  2
    # "children" 0 "Adam"
    # "children" "Adam" "Beth"
    # "children" "Beth" "Chloe"
    # "children" "Chloe" 3
    # "root" "children" 3
    #
    # each structure has an entry in "root" that specifies the number of values
    # each "list" has a 0 -> entry 1 -> entry2 -> end index structure
    #
    # -----------------------------------------------------------------------------
    def output_triples(self, outfile):
        with open(outfile, "w") as f:
            for t in self.triples:
                counter = 0
                for item in t:
                    counter += 1
                    f.write(self.reformat(item))
                    if counter < 3:
                        f.write('\t')
                f.write('\n')

    # -------------------------------------------------------------------------
    # read_json
    #
    # -------------------------------------------------------------------------
    def read_json(self, file):
        data = None
        with open(file) as f:
            try:
                data = json.load(f)
                if not data:
                    sys.stderr.write("Empty json file skipped: " + str(file))
                    return False
            except json.JSONDecodeError:
                sys.stderr.write("Invalid json file skipped: " + str(file))
        return data

    # -------------------------------------------------------------------------
    # process
    # TODO: Update to contain the steps from the main below that process
    # files once DataFingerprint can accept/handle a list of files to process
    # -------------------------------------------------------------------------
    def process(self):
        # filepath can be a single file, a list of files, or a directory of files
        file_paths = self.file_paths
        if file_paths is None:
            raise ValueError("DataFingerprint requires a list of one or more 'file_path'")

        for file_path in file_paths:
            print(file_path)
            # For multiple json files in a directory
            if os.path.isdir(file_path):
                file_list = glob.glob(os.path.join(file_path, '*.json'))
                id_list = []
                fp_list = []
                statement_list = []
                n = 0
                for file in file_list:
                    patient_file = os.path.basename(file)           # file name without path
                    patient_id = os.path.splitext(patient_file)[0]  # name of file is patient ID
                    data = self.read_json(file)
                    if data:
                        self.recurse_structure(data)                        # compute data fingerprint
                        id_list.append(patient_id)                              # record patient ID
                        if self.norm:                                                # record normalized data fingerprint
                            fp_list.append(np.round(self.normalize(), self.decimal))
                        else:                                                   # record original data fingerprint
                            fp_list.append(np.round(self.fp, self.decimal))
                        statement_list.append(self.statements)              # record # of statements used
                        # output triple statements
                        if self.tripler:
                            self.output_triples(os.path.join(file_path, "") + patient_id + '.triple')
                        # output fingerprint to screen
                        fp_string = '\t'.join(str(round(i, self.decimal)) for i in self.fp)
                        print(patient_id + '\t' + str(self.statements) + '\t' + fp_string)
                        self.reset()                                        # reset for next patient
                        n += 1                                                  # keep track of valid patients
                    # output all fingerprints to a file
                    outfile = os.path.join(file_path, "") + 'out.fp'
                    with open(outfile, "w") as f:
                            for i in range(n):
                                f.write(id_list[i] + '\t')
                                f.write(str(statement_list[i]) + '\t')
                                for j in fp_list[i]:
                                    f.write(str(j))
                                    f.write('\t')
                                f.write('\n')
            # For single json file
            else:
                patient_id = os.path.splitext(os.path.basename(file_path))[0]
                data = self.read_json(file_path)
                if data:
                    self.recurse_structure(data)
                    if self.tripler:
                        self.output_triples(patient_id + '.triple')
                    # output fingerprint to screen
                    if self.norm:  # record normalized data fingerprint
                        fp_string = '\t'.join(str(round(i, self.decimal)) for i in self.normalize())
                        print(patient_id + '\t' + str(self.statements) + '\t' + fp_string)
                    else:  # record original data fingerprint
                        fp_string = '\t'.join(str(round(i, self.decimal)) for i in self.fp)
                        print(patient_id + '\t' + str(self.statements) + '\t' + fp_string)

# -------------------------------------------------------------------------
# main
#
# -------------------------------------------------------------------------
@click.command()
@click.option('--file_path', '--path', '--input', '-i', '--dir', multiple=True, required=True,
    help="The file path to a JSON file, multiple JSON files or directory of JSON files to process and create a fingerprint")
@click.option('--debug', default=1, type=click.IntRange(0, 10, clamp=True),
    help="Level of debugging statements to output")
@click.option('--tripler/--no-tripler', default=False,
    help="Output a name/key/cargo tab delimited list of entries in json file(s)")
@click.option('--normalize/-no-normalize', default=False, help="Normalize fingerprint")
@click.option('--fp-length', default=13,
    help="The length of the fingerprint to generate.")
def main(file_path, debug, tripler, normalize, fp_length):
    params = {
        'L': fp_length,
        'norm': normalize,
        'debug': debug,
        'tripler': tripler,
        'file_paths': file_path,  # a tuple of one or more files or directories
    }

    FPrinter = DataFingerprint(**params)          # create DataFingerprint object
    FPrinter.process()

if __name__ == '__main__':
    main()