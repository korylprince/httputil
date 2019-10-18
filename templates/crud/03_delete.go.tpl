{{- $table := .Table -}}
{{- $aliases := .Aliases -}}
{{- $alias := $aliases.Table $table.Name -}}
{{- $name := $alias.UpSingular -}}
{{- $pkg := .PkgName}}

func Delete{{$name}}(r *http.Request, tx *sql.Tx) (int, interface{}) {
    vars := mux.Vars(r)
	id := vars[{{$pkg}}.{{$name}}Columns.ID]

    {{if not (eq (len $table.FKeys) 0)}}
    var (
        {{$table.Name}} *{{$pkg}}.{{$name}}
        err error
    )
    {{range $idx, $fkey := $table.FKeys}}
    {{if eq $idx 0}}if{{else}}} else if{{end}}
    fid := vars[{{$pkg}}.{{$name}}Columns.{{index $alias.Columns .Column}}]; fid != "" {
        vars[{{$pkg}}.{{$name}}Columns.ID] = fid
        delete(vars, {{$pkg}}.{{$name}}Columns.{{index $alias.Columns .Column}})
        code, {{.ForeignTable}} := Read{{($aliases.Table .ForeignTable).UpSingular}}(r, tx)
        if err, ok := {{.ForeignTable}}.(error); ok {
            return code, err
        }
        {{$table.Name}}, err = ({{.ForeignTable}}.(*{{$pkg}}.{{($aliases.Table .ForeignTable).UpSingular}})).{{$name}}s(qm.Where("id = ?", id)).One(r.Context(), tx)
    {{end}}
    } else {
        {{$table.Name}}, err = {{$pkg}}.Find{{$name}}(r.Context(), tx, id)
    }
    {{else}}
	{{$table.Name}}, err := {{$pkg}}.Find{{$name}}(r.Context(), tx, id)
    {{- end}}
	if err != nil {
		if strings.Contains(err.Error(), "no rows in result set") {
			return http.StatusNotFound, fmt.Errorf("{{$name}} %s does not exist", id)
		}

		return http.StatusInternalServerError, fmt.Errorf("Unable to find {{$name}} %s: %v", id, err)
	}

    {{range $table.ToManyRelationships}}
    {{- $fname := ($aliases.Table .ForeignTable).UpSingular -}}
	{{.ForeignTable}}s, err := {{$table.Name}}.{{$fname}}s().All(r.Context(), tx)
	if err != nil {
		return http.StatusInternalServerError, fmt.Errorf("Unable to find {{$name}} %s {{$fname}}s: %v", id, err)
	}
	if len({{.ForeignTable}}s) > 0 {
		return http.StatusConflict, fmt.Errorf("{{$name}} %s still in use", id)
	}

    {{end}}
	if _, err = {{$table.Name}}.Delete(r.Context(), tx); err != nil {
		return http.StatusInternalServerError, fmt.Errorf("Unable to delete {{$name}} %s: %v", id, err)
	}

	return http.StatusOK, nil
}
