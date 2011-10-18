document.observe('dom:loaded', function() {
	intializeListeners();
});

var intializeListeners = function(){
	$$(".save").each(function(save){
		save.observe('click', function() {
			$("div_" + save.id).style.backgroundColor = "#BFFFC0";
		});
		
	});	
}

var reloadTerm = function(dom_id, term_id, doc_id) {
	console.log(dom_id, term_id, doc_id);
	console.log($("title_" + dom_id).readAttribute("value", null));
	// new Ajax.Request('/documents/disambiguate_term', {
 //        method: 'post',
 //        parameters: "yooo son",
 //        onFailure: function() {
 //            console.log('FAIL');
 //        },
 //        onSuccess: function() {
 //        	console.log('SUCCESS');
 //        }.bind(this)
 //    });
}