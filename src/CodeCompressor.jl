module CodeCompressor

using MLStyle

export compresscode, compresssource, @compresscode_str

@data CodeState begin 
    InitCode
    NormalCode(instring::Bool, bracketnest::Int, sind::Int)
    NormalString(instring::Bool, istriple::Bool, sind::Int)
    CommandString(instring::Bool, istriple::Bool, sind::Int) 
    Comment(instring::Bool, islines::Bool, sind::Int)
end
#strings = Set([normalstring, triplestring, commandstring])



"""
    compresscode(code; deletespace=true, deletebreak=true, deletecomment=true)

compresscode returns compressed code.

If you want to compress jl file, you use `compresssource`.

# Examples
```jldoctest
julia> compresscode("
   a =   1 +1
println(a, true ? 10 :1);
")
"a = 1 +1;println(a, true ? 10 :1);"
```
"""
function compresscode(code; deletespace=true, deletebreak=true, deletecomment=true)
    begin 
        eval(code)
    end

    io = IOBuffer()
    state = CodeState[InitCode]
    codelength = length(code)
    ind = 1
    bracketcount = 0
    wio(s) = write(io, s)
    while ind <= codelength
        @match state[end] begin
            InitCode => begin
                while ind <= codelength
                    c = code[ind]
                    if !deletespace && c in " \t"
                        break
                    elseif !deletebreak && c == '\n'
                        break
                    else
                        break
                    end
                    ind += 1
                end
                pop!(state)
                push!(state, NormalCode(false, 0, ind))
            end
            NormalCode(instring, bracketnest, sind) => begin
                c = code[ind]
                writeup = true
                adds = ""
                bind = ind-1
                # for commen
                if c == '#'
                    if code[ind+1] == '='
                        push!(state, Comment(instring, true, ind))
                    else
                        eind = ind
                        while eind <= codelength && code[eind] != '\n'
                            eind += 1
                        end
                        ind = eind
                        if deletecomment
                            writeup = false
                        else
                            bind = eind-1
                        end
                        pop!(state)
                        push!(state, NormalCode(instring, bracketcount, ind))
                    end
                # for string
                elseif c == '"'
                    if code[ind+1:ind+2] == "\"\""
                        push!(state, NormalString(instring, true, ind))
                    else
                        push!(state, NormalString(instring, false, ind))
                    end
                # for command
                elseif c == '`'
                    if code[ind+1:ind+2] == "``"
                        push!(state, CommandString(instring, true, ind))
                    else
                        push!(state, CommandString(instring, false, ind))
                    end
                elseif c == '('
                    bracketcount += 1
                    writeup = false
                    ind += 1
                elseif c == ')'
                    # for code in string
                    bracketcount -= 1
                    ind += 1
                    writeup = false
                    if instring && bracketnest == bracketcount
                        pop!(state)
                    end
                # for break
                elseif deletebreak && c == '\n'
                    adds = ";"
                    ind += 1
                    pop!(state)
                    push!(state, NormalCode(instring, bracketcount, ind))
                # for space
                elseif deletespace && c in " \t"
                    while c in " \t"
                        ind += 1
                        c = code[ind]
                    end
                    adds = " "
                    pop!(state)
                    push!(state, NormalCode(instring, bracketcount, ind))
                else
                    writeup = false
                    ind += 1
                end
                if writeup && !instring
                    wio(code[sind:bind])
                    if adds != ""
                        wio(adds)
                    end
                end
            end
            NormalString(instring, istriple, sind) => begin 
                bind = ind
                while ind <= codelength
                    if !istriple && code[ind] == '"'
                        bind = ind
                        ind += 1
                        pop!(state)
                        push!(state, NormalCode(instring, bracketcount, ind))
                        break
                    elseif istriple && code[ind:ind+2] == "\"\"\""
                        bind = ind+2
                        ind += 3
                        pop!(state)
                        push!(state, NormalCode(instring, bracketcount, ind))
                        break
                    else code[ind:ind+1] == "\$("
                        bind = ind
                        ind += 1
                        push!(NormalCode(true, bracketcount, ind))
                        break
                    end
                    ind += 1
                end
                if !instring
                    wio(code[sind:bind])
                end
            end
            CommandString(instring, istriple, sind) => begin
                c = code[ind]
            end
            Comment(instring, islines, sind) && if islines end => begin
                eind = ind+2
                while eind+1 <= codelength && code[eind:eind+1] != "=#"
                    eind += 1
                end
                if !deletecomment && !instring
                    wio(code[sind:eind+1])
                end
                ind = eind+2
                pop!(state)
                push!(state, NormalCode(instring, bracketcount, ind))
            end
        end
    end

    compcode = String(take!(io))
    close(io)

    return compcode
end


"""
    compresssource(filename, deletespace=true, deletebreak=true, deletecomment=false)

compresssource reads the jl source file and returns the compressed code.

"""
function compresssource(filename, deletespace=true, deletebreak=true, deletecomment=true)
    code = read(filename) |> String
    return compresscode(code; deletespace=deletespace, deletebreak=deletebreak, deletecomment=deletecomment)
end

"""
@compresscode_str is a macro to return compressed code.

"""
macro compresscode_str(code)
    compresscode(code)
end

end # module
