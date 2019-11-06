{{- $table := .Table -}}
{{- $aliases := .Aliases -}}
{{- $alias := $aliases.Table $table.Name -}}
{{- $name := $alias.UpSingular -}}
{{- $pkg := .PkgName}}

func Query{{$name}}s(r *http.Request, tx *sql.Tx) (int, interface{}) {
    params := r.URL.Query()
    {{if not (eq (len $table.FKeys) 0) -}}
    vars := mux.Vars(r)
    {{end -}}
    var mods []qm.QueryMod

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
        vars[{{$pkg}}.{{$name}}Columns.{{index $alias.Columns .Column}}] = fid
        mods = append(mods, qm.Where("{{$fkey.Column}} = ?", fid))
    {{- end -}}
    }
    {{end}}

    {{range $idx, $fkey := $table.FKeys}}
    if _, ok := params[{{$pkg}}.{{$name}}Columns.{{index $alias.Columns .Column}}]; ok {
        if _, ok := vars[{{$pkg}}.{{$name}}Columns.{{index $alias.Columns .Column}}]; !ok {
            mods = append(mods, qm.Where("{{$fkey.Column}} = ?", params.Get({{$pkg}}.{{$name}}Columns.{{index $alias.Columns .Column}})))
        }
    }
    {{end}}

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
    {{- $colname := index $alias.Columns .Name -}}
    {{- if and (not $pfound) (not $ffound)}}
    if _, ok := params[{{$pkg}}.{{$name}}Columns.{{$colname}}]; ok { 
        mods = append(mods, qm.Where("{{.Name}} {{if eq .Type "string"}}LIKE{{else}}={{end}} ?", params.Get({{$pkg}}.{{$name}}Columns.{{$colname}})))
    }
    {{- end -}}
    {{- end}}

    {{$table.Name}}s, err := {{$pkg}}.{{$name}}s(mods...).All(r.Context(), tx)
    if err != nil {
		if strings.Contains(err.Error(), "no rows in result set") {
			return http.StatusNotFound, errors.New("No {{$name}}s found matching query")
		}

		return http.StatusInternalServerError, fmt.Errorf("Unable to query {{$name}}s: %v", err)
	}

    if {{$table.Name}}s == nil {
        return http.StatusOK, {{$pkg}}.{{$name}}Slice{}
    }

	return http.StatusOK, {{$table.Name}}s
}
