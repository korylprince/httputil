{{- $table := .Table -}}
{{- $aliases := .Aliases -}}
{{- $alias := $aliases.Table $table.Name -}}
{{- $name := $alias.UpSingular -}}
{{- $pkg := .PkgName}}

{{range $table.ToManyRelationships}}
{{if .ToJoinTable}}
{{$fname := ($aliases.Table .ForeignTable).UpSingular}}
func Relate{{$name}}{{$fname}}(r *http.Request, tx *sql.Tx) (int, interface{}) {
    vars := mux.Vars(r)

    vars[{{$pkg}}.{{$name}}Columns.ID] = vars["{{.JoinLocalColumn}}"] 
    delete(vars, "{{.JoinLocalColumn}}")
    code, v := Read{{$name}}(r, tx)
    if err, ok := v.(error); ok {
        return code, err
    }
    {{$table.Name}} := v.(*{{$pkg}}.{{$name}})

    vars[{{$pkg}}.{{$name}}Columns.ID] = vars["{{.JoinForeignColumn}}"] 
    delete(vars, "{{.JoinForeignColumn}}")
    code, v = Read{{$fname}}(r, tx)
    if err, ok := v.(error); ok {
        return code, err
    }
    {{.ForeignTable}} := v.(*{{$pkg}}.{{$fname}})

    ok, err := {{$table.Name}}.{{$fname}}s(qm.Where("id = ?", {{.ForeignTable}}.ID)).Exists(r.Context(), tx)
    if err != nil {
        return http.StatusInternalServerError, fmt.Errorf("Unable to check if {{$name}} related to {{$fname}}: %v", err)
    }
    if ok {
        return http.StatusOK, nil
    }

    if err := {{$table.Name}}.Add{{$fname}}s(r.Context(), tx, false, {{.ForeignTable}}); err != nil {
        return http.StatusInternalServerError, fmt.Errorf("Unable to relate {{$name}} to {{$fname}}: %v", err)
    }

	return http.StatusOK, nil
}

func Unrelate{{$name}}{{$fname}}(r *http.Request, tx *sql.Tx) (int, interface{}) {
    vars := mux.Vars(r)

    vars[{{$pkg}}.{{$name}}Columns.ID] = vars["{{.JoinLocalColumn}}"] 
    delete(vars, "{{.JoinLocalColumn}}")
    code, v := Read{{$name}}(r, tx)
    if err, ok := v.(error); ok {
        return code, err
    }
    {{$table.Name}} := v.(*{{$pkg}}.{{$name}})

    vars[{{$pkg}}.{{$name}}Columns.ID] = vars["{{.JoinForeignColumn}}"] 
    delete(vars, "{{.JoinForeignColumn}}")
    code, v = Read{{$fname}}(r, tx)
    if err, ok := v.(error); ok {
        return code, err
    }
    {{.ForeignTable}} := v.(*{{$pkg}}.{{$fname}})

    ok, err := {{$table.Name}}.{{$fname}}s(qm.Where("id = ?", {{.ForeignTable}}.ID)).Exists(r.Context(), tx)
    if err != nil {
        return http.StatusInternalServerError, fmt.Errorf("Unable to check if {{$name}} related to {{$fname}}: %v", err)
    }
    if !ok {
        return http.StatusOK, nil
    }

    if err := {{$table.Name}}.Remove{{$fname}}s(r.Context(), tx, {{.ForeignTable}}); err != nil {
        return http.StatusInternalServerError, fmt.Errorf("Unable to unrelate {{$name}} to {{$fname}}: %v", err)
    }

	return http.StatusOK, nil
}

func Read{{$name}}{{$fname}}s(r *http.Request, tx *sql.Tx) (int, interface{}) {
    vars := mux.Vars(r)

    vars[{{$pkg}}.{{$name}}Columns.ID] = vars["{{.JoinLocalColumn}}"] 
    delete(vars, "{{.JoinLocalColumn}}")
    code, v := Read{{$name}}(r, tx)
    if err, ok := v.(error); ok {
        return code, err
    }
    {{$table.Name}} := v.(*{{$pkg}}.{{$name}})

    {{.ForeignTable}}s, err := {{$table.Name}}.{{$fname}}s().All(r.Context(), tx)
    if err != nil {
        return http.StatusInternalServerError, fmt.Errorf("Unable to read {{$name}} {{$fname}}s: %v", err)
    }

    if {{.ForeignTable}}s == nil {
        return http.StatusOK, {{$pkg}}.{{$fname}}Slice{}
    }

	return http.StatusOK, {{.ForeignTable}}s
}
{{end}}
{{end}}
