{{- $table := .Table -}}
{{- $aliases := .Aliases -}}
{{- $alias := $aliases.Table $table.Name -}}
{{- $name := $alias.UpSingular -}}
{{- $pkg := .PkgName}}

func Create{{$name}}(r *http.Request, tx *sql.Tx) (int, interface{}) {
    {{- if not (eq (len $table.FKeys) 0)}}
    vars := mux.Vars(r)

    {{end}}

	{{- $table.Name}} := new({{$pkg}}.{{$name}})
	if err := jsonapi.ParseJSONBody(r, {{$table.Name}}); err != nil {
		return http.StatusBadRequest, err
	}

    {{if not (eq (len $table.FKeys) 0)}}
    {{range $idx, $fkey := $table.FKeys}}
    {{if eq $idx 0}}if{{else}}} else if{{end}}
    fid := vars[{{$pkg}}.{{$name}}Columns.{{index $alias.Columns .Column}}]; fid != "" {
        vars[{{$pkg}}.{{$name}}Columns.ID] = fid
        delete(vars, {{$pkg}}.{{$name}}Columns.{{index $alias.Columns .Column}})
        code, {{.ForeignTable}} := Read{{($aliases.Table .ForeignTable).UpSingular}}(r, tx)
        if err, ok := {{.ForeignTable}}.(error); ok {
            return code, err
        }
        {{$table.Name}}.{{index $alias.Columns .Column}} = fid
    {{end -}}
    }
    {{end}}

	if err := {{$table.Name}}.Insert(r.Context(), tx, boil.Blacklist(
		{{$pkg}}.{{$name}}Columns.ID,
	)); err != nil {
        if strings.Contains(err.Error(), "duplicate key value violates") {
            return http.StatusBadRequest, fmt.Errorf("Unable to insert duplicate {{$name}}: %v", err)
        } else if strings.Contains(err.Error(), "value too long for type character varying") {
            return http.StatusBadRequest, fmt.Errorf("Unable to insert invalid {{$name}}: %v", err)
        } else if strings.Contains(err.Error(), "invalid input syntax for type uuid") {
            return http.StatusBadRequest, fmt.Errorf("Unable to insert invalid {{$name}}: %v", err)
        } else if strings.Contains(err.Error(), "violates foreign key constraint") {
            return http.StatusBadRequest, fmt.Errorf("Unable to insert invalid {{$name}}: %v", err)
        }
        return http.StatusInternalServerError, fmt.Errorf("Unable to insert {{$name}}: %v", err)
	}

	return http.StatusOK, {{$table.Name}}
}
