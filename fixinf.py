import re,subprocess,sys
# Repeatedly run check, and for "Cannot infer the type of X" errors, convert := to explicit Variant-less typing by using "var X = " (untyped).
for it in range(60):
    out=subprocess.run(["./check.sh"],capture_output=True,text=True).stdout
    m=re.search(r'Cannot infer the type of "(\w+)".*?\n\s*at: GDScript::reload \((res://[^:]+):(\d+)\)',out,re.S)
    if not m:
        print(out[:1500] if out.strip() else "CLEAN"); break
    var,f,ln=m.group(1),m.group(2).replace("res://",""),int(m.group(3))
    lines=open(f).read().split("\n")
    L=lines[ln-1]
    nl=re.sub(r'\bvar %s :=' % var, 'var %s =' % var, L,1)
    if nl==L:
        print("no change",f,ln,L); break
    lines[ln-1]=nl
    open(f,"w").write("\n".join(lines))
    print("fixed",f,ln,var)
