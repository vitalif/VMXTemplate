<html>
<head>
</head>
<body>
<div>x{intro}y</div>
<select>
    <!-- FOR o = options -->
    <option value="{o.url}"<!-- IF o.selected --> selected="selected"<!-- END -->>{o.name}</option>
    <!-- END -->
</select>
<span>{v.end('x', 'y')['z'].begin()}</span>
</body>
</html>
