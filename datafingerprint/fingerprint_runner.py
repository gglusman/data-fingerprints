################@Author: Arpita Joshi###########################
###########  Modifications to Denise's and Jewel's code  to get one fingerprint vector for each row entry in a JSON object (one file with patients as different rows)######

#from Json2Vec import *
import sys
import json
import itertools
#from json2fp import *
import pandas as pd


def isnumeric(n):
	if isinstance(n, float):
		return True
	if isinstance(n, int):
		return True
	#if isinstance(n, str):
		#return False
		
	#else:
		#from re import match
		#return bool(match(r'[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?', str(n)))
	return False




def frexp10(n):
        if n == 0:
            return 0.0, 0
        else:
            e = int(math.log10(abs(n)))
            m = n/10**e
            return m, e

  ## vector_value# compute the value of the first argument in vector form ## 

def vector_value(o):
	length = L
	new = np.zeros(length)

	# for NUMBERS encoding
	if isnumeric(o):
		# if it's null value zero
		if not o:
			return new
			# -----------------------------------------------------------------
			# number method #1: ME (Mantissa/Exponent)
		elif numeric_encoding == "ME":
			mantissa, exponent = frexp10(o)
			# encode mantissa - a fraction in range (-1~1)
			mantissa *= (length / 10.0)  # make mantissa in the range of -L to L
			over = abs(mantissa - int(mantissa))
			exp_w = exponent_weight
			man_w = 1-exp_w
			if over: #> np.finfo(float).eps:
				new[int(mantissa % length)] += man_w*(1 - over)
				index = mantissa + 1 if mantissa > 0 else mantissa - 1
				new[int(index % length)] += man_w*over
			else: # in what case it will come to here?
				new[int(mantissa % length)] += man_w#1
				# encode the exponent - an integer, which can be negative
			new[int(exponent % length)] += exp_w#1

		else:
			new[int(o % length)] += 1

	elif(isinstance(o,(str,bool))):
		
		decay = string_encoding_decay if string_encoding_decay else 0.1
		remain = (1 - decay)
		#print(isinstance(o,str))
		if(isinstance(o,bool)):
			o = str(o)
		v = ord(o[0])
		new[int(v % length)] += 1
		for i in range(1, len(o)):
			v = v*remain + ord(o[i])*decay
			#if self.debug > 5:
				#print("#decay: %s %d %d %.4f" % (o, i, ord(o[i]), v))
			sv = v*length/10.0
			over = sv - int(sv)   
			new[int(sv % length)] += (1-over)
			new[int((sv+1) % length)] += over

	# normalize to a unit vector (sum of 1)
	new = np.array(new) - min(new)
	if sum(new) != 0:
		new = np.array(new) / sum(new)

	return new

'''
 ## add_vector_value## 
def add_vector_value(v1, v2, v3, stuff=None):
        length = L
        for j in range(length):
            v = (v1[j] + v2[int((j+1) % length)] + v3[int((j+2) % length)])/3
            fp[j] += v
'''

def add_vector_value(v1, v2, v3, stuff=None):
	length = L
	tmp = np.zeros(length)
	for i in range(length):
		xx = 1+abs(v1[i] * math.cos(v1[i]))
		yy = 1+abs(v2[i] * math.cos(2*v2[i]))
		zz = 1+abs(v3[i] * math.cos(3*v3[i]))
		tmp[i] = (xx*yy*zz)**(1/3) - 1
	tmp = np.array(tmp) - min(tmp)
	if sum(tmp) != 0:
		tmp = np.array(tmp) / sum(tmp)
	for j in range(length):
		fp[j] = tmp[j]

 ## recurseStructure##
def recurse_structure(obj, name=None, base=None):
	if name is None: name = 'root'
	if base is None: base = vector_value(0)
        # -------------------------------------------------------------------------
        # TYPE 1 data: python dictionary
	global statements
	if isinstance(obj, dict):
		keys_used = 0
		for key, cargo in obj.items():
			#print(cargo)
		# skip empty strings, null value, careful about integer "0" @Arpita: Took care of it in main()
			#if not(cargo): print(cargo)
			if (cargo or isinstance(cargo, int)):
				vkey = vector_value(key)
				if isinstance(cargo, (list, dict)):
			# if it's another list or dict, cargo is the keys_used (length)
					cargo = recurse_structure(cargo, key, vkey)
				add_vector_value(base, vkey, vector_value(cargo),("#hash_entry", name, key, cargo))
				triples.append(list([name, key, cargo]))
				keys_used += 1   # number of statements used in generating this vector
		statements += keys_used
		return keys_used
        
	else:
		return obj


def normalize(temp_fp,key):
	return (np.array(temp_fp)-np.mean(temp_fp)) / np.std(temp_fp)
	

def reset():
	global fp
	global statements
	global triples
	fp = np.zeros(L)
	statements = 0
	triples = []
    
def main():
	
	for key,item in data.items():
		#print(item)
		#fp_vect = np.zeros(L)	
		recurse_structure(item)
		#fp_vect = fp
		global fp
		if(not(np.all((fp == 0)))):
			tfp = normalize(fp,key)
			
			print(key,end='\t')
			print(statements,end='\t')
			for i in range(len(fp)):
				if i < L-1:
					print(round(tfp[i],decimal),end='\t')
				else: print(round(tfp[i],decimal))
		reset()

	
with open(sys.argv[1]) as f:
	data = json.load(f)
#data = dict(itertools.islice(data.items(), 1))	
L = int(sys.argv[2])	
#norm = int(sys.argv[3]) @Arpita: Normalization happens anyway
root = 'root'
numeric_encoding = 'ME'    # ME
string_encoding = 'decay'  # decay
string_encoding_decay = 0.1
decimal = 3
exponent_weight = 0.5
fp = np.zeros(L)
statements = 0
triples = []


if __name__ == "__main__":
	main()
