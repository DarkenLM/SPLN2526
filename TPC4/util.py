from collections import Counter
from functools import cmp_to_key

def _pp_counter_sort(a, b):
    if (a[1] > b[1]): return 1
    if (a[1] < b[1]): return -1
    return a[0][0] > b[0][0]

def prettyprint(obj, n = 0, ident = "  ", listSplitDepth = 1):
    curIndent = (ident * n)
    s = curIndent
    if (isinstance(obj, list)):
        s += "["
        if (listSplitDepth > 0):
            s += "\n"
            for i in range(0, len(obj)): 
                s += prettyprint(obj[i], n=n + 1, listSplitDepth=listSplitDepth - 1)
                if (i < len(obj) - 1): s += ",\n"
            s += f"\n{curIndent}]"
        else: 
            for i in range(0, len(obj)): 
                s += prettyprint(obj[i], n=0, listSplitDepth=0)
                if (i < len(obj) - 1): s += ", "
            s += f"]"
    elif (isinstance(obj, Counter)):
        nextIndent = curIndent + ident
        s += "Counter({\n"
        items = list(sorted(list(obj.items()), key=cmp_to_key(_pp_counter_sort), reverse=True))
        for i in range(0, len(obj)):
            s += nextIndent + f"{items[i]}"
            if (i < len(obj) - 1): s += ",\n"
        s += f"\n{curIndent}}})"
    elif (isinstance(obj, str)):
        s += f"\"{obj}\""
    else:
        s += f"{obj}"
    
    return s

def tabulate(arr, headers = None, separateBetweenRows = False, border = True):
    columns = len(arr[0])

    if (headers == None): headers = [""] * columns
    assert len(headers) == columns, f"Invalid headers list: Must have {columns} elements."

    # Split multiline and create matrix
    matrix = [[] for _ in range(0, columns)]
    maxlens = [len(h) for h in headers]
    rowGroups = []

    # for i in range(0, columns):
    for i in range(0, len(arr)):
        nrows = [[] for _ in range(0, columns)]
        maxrows = 0

        # Split into lines
        for j in range(0, columns):
            nr = f"{arr[i][j]}".split("\n")
            if (len(nr) > maxrows): maxrows = len(nr)
            nrows[j].extend(nr)

        # Guarantee that every column has the same size to prevent misalignment on the matrix
        for j in range(0, columns):
            for _ in range(len(nrows[j]), maxrows): nrows[j].append("")
            matrix[j].extend(nrows[j])

        rowGroups.append(len(matrix[0]) - 1)
    
    maxmatrows = len(matrix[0])
    rowGroups.pop(len(rowGroups) - 1)

    # Calculate maximum column width for every column
    for i in range(0, columns):
        for row in matrix[i]: 
            if (len(row) > maxlens[i]): maxlens[i] = len(row)

    # Pad every row to match the column width
    for i in range(0, columns):
        for j in range(0, maxmatrows): matrix[i][j] = matrix[i][j].ljust(maxlens[i], " ")

    s = ""
    sep = ""
    if (border):
        for i in range(0, columns):
            header = headers[i].ljust(maxlens[i], " ") 
            s += header
            sep += "-" * len(header)
            if (i < columns -1): 
                s += " | "
                sep += "-+-"
        s += "\n" + sep + "\n"

    for i in range(0, maxmatrows):
        for j in range(0, columns):
            s += matrix[j][i]
            if (j < columns - 1): s += " | " if border else " "

        s += "\n"
        if (separateBetweenRows and (i in rowGroups)): s += sep + "\n"

    # return s[:-1]
    return s.strip()
