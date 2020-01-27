# -----------------------------------------------------------------------------
# tripler.py
# read json file and generate tab-delimited triple statements
# USAGE: python3 tripler <name_of_input_file> or <directory_of_input_files>
#
# by Jewel Y. Lee (jlee@systemsbiology.org), last updated on 2/6/19
# -----------------------------------------------------------------------------
import os
import sys
import json
import csv
import glob

# -----------------------------------------------------------------------------
# read_json
# read input json files and skip any empty json object or invalid json files
# -----------------------------------------------------------------------------
def read_json(file):
    data = None
    with open(file) as f:
        try:
            data = json.load(f)
            if not data:
                print("Skipped empty json file: " + str(file))
                pass
        except:
            print("Skipped invalid json file: " + str(file))
            pass
    return data

# -----------------------------------------------------------------------------
# get_triple
# the recursive parser that takes json object and extract triples
# -----------------------------------------------------------------------------
def get_triple(obj, name=None, result=None):
    if not name: name = 'root'
    if not result: result = []
    # -------------------------------------------------------------------------
    # TYPE 1 data: python dictionary, perl hashes
    if isinstance(obj, dict):
        for key, cargo in obj.items():
            if not cargo:
                continue
            elif isinstance(cargo, list):
                # special case
                if len(cargo) == 1:
                    if isinstance(cargo[0], (str, int)):
                        result.append(list([name, key, cargo[0]]))
                    else:
                        result.append(list([name, key, len(cargo[0])]))
                        result = get_triple(cargo[0], key, result)
                else:
                    # get the non-empty, not null list items
                    valid = 0
                    for c in cargo:
                        if c: valid += 1
                    result.append(list([name, key, len(cargo)]))
                    result = get_triple(cargo, key, result)
            elif isinstance(cargo, dict):
                if len(cargo) == 1:
                    result.append(list([name, key, len(cargo)]))
                    result = get_triple(cargo, key, result)
                else:
                    # get the non-empty, not null list items
                    valid = 0
                    for k2, v2 in cargo.items():
                        if v2: valid += 1
                    result.append(list([name, key, valid]))
                    result = get_triple(cargo, key, result)
            # case: sets instead of dictionary
            elif isinstance(cargo, set):
                for value in cargo:
                    result.append(list([name, key, value]))
            # case: Key-value pair
            else:
                result.append(list([name, key, cargo]))
    # -------------------------------------------------------------------------
    # TYPE 2 data: python list, perl arrays
    elif isinstance(obj, list):
        if len(obj) == 1:
            # structure has an extra layer, recurse its content directly
            if isinstance(obj, (list, dict, tuple)):
                result = get_triple(obj[0], name, result)
            # key-value pair has an extra layer, retrieve key-value
            else:
                result.append(list([name, obj, obj[0]]))
        else:
            ## new version: no duplicated info
            prev = 0
            for i in range(0, len(obj)):
                if isinstance(obj[i], (list, dict, tuple)):
                    curr = len(obj[i])
                else:
                    curr = obj[i]
                result.append(list([name, prev, curr]))
                result = get_triple(obj[i], name, result)
                prev = curr
            result.append(list([name, curr, len(obj)]))
            ## old versions
            #
            # for item in obj:
            #     result = get_triple(item, name, result)
            # result.append(list([name, 0, obj[0]]))
            # for i in range(1, len(obj)):
            #     result.append(list([name, obj[i-1], obj[i]]))
            # result.append(list([name, obj[len(obj)-1], len(obj)]))
    else:
        return result

# -----------------------------------------------------------------------------
# reformat
#
# -----------------------------------------------------------------------------
def reformat(value):
    if isinstance(value, int):
        value = str(value)
    else:
        value = '"{}"'.format(value)
    return value

# -----------------------------------------------------------------------------
# write_triple
#
# -----------------------------------------------------------------------------
def write_triple(outfile, statements):
    with open(outfile, "w") as f:
        for triple in statements:
            counter = 0
            for item in triple:
                counter += 1
                f.write(reformat(item))
                if counter < 3:
                    f.write('\t')
            f.write('\n')

# -----------------------------------------------------------------------------
# read_triple
#
# -----------------------------------------------------------------------------
def read_triple(infile):
    statements = []
    with open(infile, 'r') as f:
        reader = csv.reader(f, delimiter='\t')
        for x, y, z in reader:
            statements.append(list([x, y, z]))
    return statements

# -----------------------------------------------------------------------------
# main
# 
# -----------------------------------------------------------------------------
def main():
    assert len(sys.argv) > 1, "Usage: python3 tripler.py <single_json_file> or <directory_of_multiple_json_files>\n"
    file_path = sys.argv[1]
    if os.path.isdir(file_path):
        # multiple json files
        file_list = glob.glob(os.path.join(file_path, '*.json'))
        for file in file_list:
            data = read_json(file)
            statements = get_triple(data)
            outfile = os.path.splitext(file)[0] + ".triple"
            write_triple(outfile, statements)
    else:
        # single json file
        file = file_path
        data = read_json(file)
        triples = get_triple(data)
        outfile = os.path.splitext(file)[0] + ".triple"
        write_triple(outfile, triples)

if __name__ == "__main__":
    main()
