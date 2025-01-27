var reportID = 'reportArea';
printReport(reportID);

function printReport(printPage) 
{ 
    var headstr = "<html><head><title></title></head><body>"; 
    var footstr = "</body>"; 
    var newstr = document.all.item(printPage).innerHTML; 
    var oldstr = document.body.innerHTML; 
    document.body.innerHTML = headstr+newstr+footstr; 
    window.print(); 
    window.location.reload(true); 
    runReport();
    return false; 
} 
