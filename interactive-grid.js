apex.region("PO_RATE_UPDATE").widget().interactiveGrid("getActions").invoke("save");
--Save Grid data


(function($) {
    function update(model, columnName, pageItem) {
        var columnKey = model.getFieldKey(columnName),
            total = 0;

        // console.log(`>> Starting sum for column: ${columnName}`);
        model.forEach(function(record, index, id) {
            var value = parseFloat(record[columnKey]),
                meta = model.getRecordMetadata(id);

            if (!isNaN(value) && !meta.deleted && !meta.agg) {
                total += value;
            }
        });
        // console.log(`>> Setting sum for column ${columnName} to ${total}`);
        total = parseFloat(total.toFixed(4));
        $s(pageItem, total);
    }

    $(function() {
        function initializeDynamicGrid(regionId, columnName, pageItem) {
            $(`#${regionId}`).on("interactivegridviewmodelcreate", function(event, ui) {
                var model = ui.model;

                if (ui.viewId === "grid") {
                    model.subscribe({
                        onChange: function(type, change) {
                            // console.log(">> Model changed ", type, change);
                            if (type === "set") {
                                if (change.field === columnName) {
                                    update(model, columnName, pageItem);
                                }
                            } else if (type !== "move" && type !== "metaChange") {
                                update(model, columnName, pageItem);
                            }
                        },
                        progressView: $(`#${pageItem}`)
                    });
                    update(model, columnName, pageItem);
                    model.fetchAll(function() {});
                }
            });
        }
        // Call the function with your dynamic values
        initializeDynamicGrid("shell-ig", "REQUIRED_QNTY", "P399_S_QTY");
        // initializeDynamicGrid("shell-ig", "STD_RATE", "P399_S_RATE");
        initializeDynamicGrid("shell-ig", "AMOUNT", "P399_S_AMOUNT");
        initializeDynamicGrid("shell-ig", "AMOUNT", "P399_S_AMOUNT_1");
        initializeDynamicGrid("shell-ig", "COST_CARTON", "P399_S_CARTON");
        initializeDynamicGrid("shell-ig", "COST_PACK", "P399_S_PACK");

        initializeDynamicGrid("cream-ig", "REQUIRED_QNTY", "P399_C_QTY");
        initializeDynamicGrid("cream-ig", "AMOUNT", "P399_C_AMOUNT");
        initializeDynamicGrid("cream-ig", "COST_CARTON", "P399_C_CARTON");
        initializeDynamicGrid("cream-ig", "COST_PACK", "P399_C_PACK");

        initializeDynamicGrid("p-shell-ig", "REQUIRED_QNTY", "P399_PS_QTY");
        initializeDynamicGrid("p-shell-ig", "AMOUNT", "P399_PS_AMOUNT");
        initializeDynamicGrid("p-shell-ig", "COST_CARTON", "P399_PS_CARTON");
        initializeDynamicGrid("p-shell-ig", "COST_PACK", "P399_PS_PACK");
    });
})(apex.jQuery);


function setFlag(regionID) {
    console.log(regionID);
    var view = apex.region(regionID).widget(). interactiveGrid("getViews", "grid"), menu$ = view.selActionMenu$; 
    var i, records = view.getSelectedRecords(), total = 0, cnt = 0;
    for (i = 0; i< records.length; i++) {
        view.model.setValue(records[i], "FLAG", 'Y'); 
        cnt = cnt + 1;

    }
    return records.length;
}


function selectAllRows(gridId) {
    var selectAllCheckbox = document.querySelector(`#${gridId} th.a-GV-selHeader span.u-selector`);
    if (selectAllCheckbox) {
        // Check if the checkbox is not checked
        if (selectAllCheckbox.getAttribute('aria-checked') === 'false') {
            selectAllCheckbox.click();
        } else {
            console.log(`Select All checkbox is already checked for grid ID: ${gridId}.`);
        }
    } else {
        console.log(`Select All checkbox not found for grid ID: ${gridId}. Verify the selector or grid ID.`);
    }
}


var regionInfo = [
    { regionID: 'shell-ig', itemID: 'P399_S_YIELD_1', itemName: 'Raw Material Shell Yield' },
   { regionID: 'cream-ig', itemID: 'P399_c_YIELD', itemName: 'Raw Material Cream Yield' },
   { regionID: 'p-shell-ig', itemID: 'P399_PS_YIELD', itemName: 'Packing Material Shell Yield' }
];

function velidityCheck() {
    for (let i = 0; i < regionInfo.length; i++) {
        var region = regionInfo[i];
        var rowCount = apex.region(region.regionID).widget().interactiveGrid("getViews", "grid").model.getTotalRecords();
        if (rowCount > 0 && $v(region.itemID) === "") {
            apex.message.clearErrors();
            apex.message.showErrors([
                {
                    type:       "error",
                    location:   [ "page", "inline" ],
                    pageItem:   region.itemID,
                    message:    region.itemName+" is required!",
                    unsafe:     false
                }
            ]);
            return 0; // Exit the loop and return 0 immediately
        }
    }
    return 1; // All validations passed
};


function saveDate(){
    let rowCount = 0, totalRecord = 0;
    for (let i = 0; i < regionInfo.length; i++) {
        var region = regionInfo[i];
        selectAllRows(region.regionID);
        rowCount = setFlag(region.regionID);

        totalRecord += rowCount;
    }
    console.log(totalRecord);
    $s("P399_TOTAL_ITEM", totalRecord);
    apex.submit();
};

--save button hide
button[data-action="save"] {
    display: none !important;
}

-----------download----------------

apex.region("salarySummary").widget().interactiveGrid("getActions").invoke("show-download-dialog");


var ig$ = apex.region("salarySummary").widget();
ig$.interactiveGrid("getActions").invoke("show-download-dialog");

$("div[aria-labelledby='ui-id-1']").find("button").each(function(){
  if ($(this).html() == "Download") {
    $(this).trigger("click");
  }
});

OR


 var ig$ = apex.region("salarySummary").widget();
 ig$.interactiveGrid("getActions").invoke("show-download-dialog");
 $("div[aria-describedby='salarySummary_ig_download_dialog']").find("button").each(function(){
   if ($(this).html() == "Download")
   {
     $(this).trigger("click");
   }
 });
