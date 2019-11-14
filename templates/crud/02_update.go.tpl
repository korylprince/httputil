{{- $table := .Table -}}
{{- $aliases := .Aliases -}}
{{- $alias := $aliases.Table $table.Name -}}
{{- $name := $alias.UpSingular -}}
{{- $pkg := .PkgName}}

func Update{{$name}}(r *http.Request, tx *sql.Tx) (int, interface{}) {
    vars := mux.Vars(r)
	id := vars[{{$pkg}}.{{$name}}Columns.ID]

	new{{$name}} := new({{$pkg}}.{{$name}})
	if err := jsonapi.ParseJSONBody(r, new{{$name}}); err != nil {
		return http.StatusBadRequest, err
	}

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

    {{range $idx, $col := $table.Columns -}}
    {{- /* is it a primary key? */ -}}
    {{- $pfound := false -}}
    {{- range $pidx, $pcol := $table.PKey.Columns -}}
        {{- if eq $col.Name $pcol -}}
            {{- $pfound = true -}}
        {{- end -}}
    {{- end -}}
    {{- /* is it a foreign key? */ -}}
    {{- $ffound := false -}}
    {{- range $fidx, $fkey := $table.FKeys -}}
        {{- if eq $col.Name $fkey.Column -}}
            {{- $ffound = true -}}
        {{- end -}}
    {{- end -}}
    {{- if not $pfound -}}
    {{- $colname := index $alias.Columns .Name -}}
    {{- if $ffound}}
    if new{{$name}}.{{$colname}} != "" {
        {{$table.Name}}.{{$colname}} = new{{$name}}.{{$colname}}
    } else if fid := vars[{{$pkg}}.{{$name}}Columns.{{$colname}}]; fid != "" {
        {{$table.Name}}.{{$colname}} = fid
    }
    {{- else}}
    {{$table.Name}}.{{$colname}} = new{{$name}}.{{$colname}}
    {{end -}}
    {{- end -}}
    {{- end}}

	if _, err = {{$table.Name}}.Update(r.Context(), tx, boil.Blacklist(
        {{range $table.PKey.Columns}}
        {{- $colname := index $alias.Columns . -}}
        {{$pkg}}.{{$name}}Columns.{{$colname}},
        {{end}}
	)); err != nil {
        if strings.Contains(err.Error(), "duplicate key value violates") {
            return http.StatusConflict, fmt.Errorf("Unable to insert duplicate {{$name}}: %v", err)
        } else if strings.Contains(err.Error(), "value too long for type character varying") {
            return http.StatusBadRequest, fmt.Errorf("Unable to insert invalid {{$name}}: %v", err)
        } else if strings.Contains(err.Error(), "violates check constraint") {
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
