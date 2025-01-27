var style = `
<style>
    table {
        width: 100%;
        border-collapse: collapse; 
        float: left; 
        margin-bottom: 10px;
    }

    th, td {
        border: 1px solid black;
    }
</style>`;
var reportID = 'reportArea'
var fileName = 'Attendance Report';
var sheetName = 'Attendance Report';

tableToExcel(reportID, fileName, sheetName);

var tableToExcel = (function () {
    // Define your style class template.
    // var style = "<style>td { border: 1px solid black; }</style>";
    var template = '<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40"><head><!--[if gte mso 9]><xml><x:ExcelWorkbook><x:ExcelWorksheets><x:ExcelWorksheet><x:Name>{worksheet}</x:Name><x:WorksheetOptions><x:DisplayGridlines/></x:WorksheetOptions></x:ExcelWorksheet></x:ExcelWorksheets></x:ExcelWorkbook></xml><![endif]-->' + style + '</head><body><table>{table}</table></body></html>';
    var format = function (s, c) {
        return s.replace(/{(\w+)}/g, function (m, p) { return c[p]; });
    };
    
    return function (table, fileName, sheetName) {
        if (!table.nodeType) table = document.getElementById(table);
        var ctx = { worksheet: sheetName || 'Worksheet', table: table.innerHTML };
        var html = format(template, ctx);

        // Create a Blob with the HTML content
        var blob = new Blob([html], { type: 'application/vnd.ms-excel' });


        var link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = (fileName || 'Worksheet') + '.xls';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    };
})();
