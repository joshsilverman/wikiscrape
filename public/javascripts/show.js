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
	$("div_" + dom_id).style.backgroundColor = "#D6D6D6";
	params = {"link" : "/wiki/" + $("title_" + dom_id).value, 
		"term_id" : term_id,
		"doc_id" : doc_id};
	
	new Ajax.Request('/documents/disambiguate_term', {
        method: 'post',
        parameters: params,
        onFailure: function() {
            alert("Lookup failed! Sorry bro :(");
        },
        onSuccess: function() {
        	callback_params = {"term_id" : term_id};
        	new Ajax.Request('/topics/get_topic', {
		        method: 'post',
		        parameters: callback_params,
		        onFailure: function() {
		            alert("Update failed!");
		        },
		        onSuccess: function(response) {
		        	var response = JSON.parse(response.request.transport.responseText)
		        	$('title_' + dom_id).value = response.topic.topic.name
		        	$('description_' + dom_id).value = response.topic.topic.description;
		   			$('question_' + dom_id).value = response.topic.topic.question;
		   		   	var answerText = "";
		   			response.answers.each(function(answer) {
		   				answerText = answerText + answer.answer.name + "\n";
		   			});
		   			alert(answerText);
		   			$('answers_' + dom_id).value = answerText;

		        	// UPDATE LINKS, ETC
        		}.bind(this)
        	});
        }.bind(this)
    });
}