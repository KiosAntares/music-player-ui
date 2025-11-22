def quant_2vec(vec):
    return (int(vec[0]),int(vec[1]))

def multiply_2vec(v1, v2):
    return (v1[0] * v2[0], v1[1] * v2[1])

def divide_2vec(v1, v2):
    return (v1[0] / v2[0], v1[1] / v2[1])

def divide_2vec_quant(v1, v2):
    return (v1[0] // v2[0], v1[1] // v2[1])

def scale_2vec(v1, scale):
    return (v1[0] * scale, v1[1] * scale)

def add_2vec(v1, v2):
    return (v1[0] + v2[0], v1[1] + v2[1])

def sub_2vec(v1, v2):
    return (v1[0] - v2[0], v1[1] - v2[1])
