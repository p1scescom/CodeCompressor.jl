module CodeCompressor

using MLStyle

export compresscode, compresssource, @compresscode_str

@data CodeState begin 
    NormalCode(instring::Bool, bracketnest::Int)
    NormalString(istriple::Bool)
    CommandString(istriple::Bool) 
    Comment(islines::Bool)
end
#strings = Set([normalstring, triplestring, commandstring])



"""
    compresscode(code; deletespace=true, deletebreak=true, deletecomment=true)

compresscode returns compressed code.

If you want to compress jl file, you use `compresssource`.

# Examples
```jldoctest
julia> compresscode("
a =   1 + 1
println(a, true ? 10 : 1);
")
"a=1+1;println(a,true?10:1)"
```
"""
function compresscode(code; deletespace=true, deletebreak=true, deletecomment=true)
    io = IOBuffer()
    state = CodeState[NormalCode(false, 0)]
    codelength = length(code)
    ind = 1
    bracketcount = 0
    wio(s) = write(io, s)
    while ind <= codelength
        @match state[end] begin
            NormalCode(instring, bracketnest) => begin
                c = code[ind]
                # for commen
                if c == '#'
                    if code[ind+1] == '='
                        push!(state, Comment(true))
                    else
                        eind = ind
                        while eind <= codelength && code[eind] != '\n'
                            eind += 1
                        end
                        if deletecomment
                            ind = eind+1
                        else
                            wio(code[ind:eind])
                            ind = eind+1
                        end
                    end
                # for string
                elseif c == '"'
                    if code[ind+1:ind+2] == "\"\""
                        push!(state, NormalString(true))
                    else
                        push!(state, NormalString(false))
                    end
                # for command
                elseif c == '`'
                    if code[ind+1:ind+2] == "``"
                        push!(state, CommandString(true))
                    else
                        push!(state, CommandString(false))
                    end
                # for code in string
                elseif instring && bracketnest == bracketcount &&  c == ')'
                elseif c == '('
                    bracketcount += 1
                elseif c == ')'
                    bracketcount -= 1
                # for break
                elseif c == '\n'
                    if deletebreak
                    else
                    end
                # for space
                elseif c != ' '
                    if deletespace
                        ind += 1
                    else
                    end
                elseif c in "+-*/÷?:;,&!"
                end
            end
            NormalString => begin 
                c = code[ind]
            end
            CommandString => begin
                c = code[ind]
            end
            Comment(islines) && if islines end => begin
                islines
                eind = ind+2
                while eind+1 <= codelength && code[eind:eind+1] != "=#"
                    eind += 1
                end
                if deletecomment
                    ind = eind+2
                else
                    wio(code[ind:eind+1])
                    ind = eind+2
                end
                pop!(state)
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
