function SetCookie (name, data) {
	DelCookie(name);
	var exdate = new Date();
	exdate.setDate(exdate.getDate() + 1);
	document.cookie = name + "=" + JSON.stringify(data);
}

function getCookie(name) {
	var cookie = " " + document.cookie;
	var search = " " + name + "=";
	var setStr = null;
	var offset = 0;
	var end = 0;
	if (cookie.length > 0) {
		offset = cookie.indexOf(search);
		if (offset != -1) {
			offset += search.length;
			end = cookie.indexOf(";", offset)
			if (end == -1) {
				end = cookie.length;
			}
			setStr = unescape(cookie.substring(offset, end));
		}
	}
	return(setStr);
}

function DelCookie (name) {
	document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:01 GMT;';
}

function removeDomain (elem, remove) {
	Hide('mzone_'+elem);
	if (window.document.getElementById('cart_'+elem)) { Hide('cart_'+elem); }

	var resp = getCookie('domains_storage');
	var lst = new Array();
	var out = new Array();
	var total = 0;
	var flag = 0;
	if (resp != null) {
		lst = JSON.parse(resp);
		if (lst.length > 0) {
			for (var i = 0; i < lst.length; i++) {
				if (lst[i] != remove) {
					flag++;
					out.push(lst[i]);
					if (window.document.getElementById('price_' + i)) {
						total = total*1 + window.document.getElementById('price_' + i).value*1;
						total = total.toFixed(2);
					}
				}
			}
			if (flag > 0) {
				SetCookie('domains_storage', out);
			}
			else {
				DelCookie('domains_storage');
			}
		}
	}

	window.document.getElementById('domain-num').innerHTML = flag;
	if (document.getElementById('newdomains')) {
		/* Recalculate price of new domains*/
		var diff = document.getElementById('diffp').value;
		var totalp = document.getElementById('totalp').value;
		diff = parseFloat(diff) + parseFloat(totalp);

		window.document.getElementById('totalprice').innerHTML = total;
		window.document.getElementById('totalp').value = total;
		diff = parseFloat(diff) - parseFloat(total);
		diff = diff.toFixed(2);

		window.document.getElementById('diffprice').innerHTML = diff;
		window.document.getElementById('diffp').value = diff;
		if (diff <= 0) {
			window.document.getElementById('diffprice').className = 'red';
			if (window.document.getElementById('addpay')) {
				Show('addpay');
			}
		}
		else {
			window.document.getElementById('diffprice').className = '';
			if (window.document.getElementById('addpay')) {
				Hide('addpay');
			}
		}
	}
	if (flag == 0) {
		if (document.getElementById('newdomains')) {
			Hide('newdomains');
		}
		if (document.getElementById('ext_5')) {
			Hide('ext_5');
		}
		if (document.getElementById('domains-storage')) {
			Hide('domains-storage');
		}
	}
}

function StoreDomain (domain) {
	var resp = getCookie('domains_storage');
	var lst = new Array();
	if (resp == null) {
		lst.push(domain);
		SetCookie('domains_storage', lst);
		ShowDomains();
	}
	else {
		lst = JSON.parse(resp);
		var flag = 0;
		for (var i = 0; i < lst.length; i++) {
			if (lst[i] == domain) {
				flag++;
			}
		}
		if (flag == 0) {
			lst.push(domain); // [lst.length]
			SetCookie('domains_storage', lst);
		}
		ShowDomains();
	}
	alert('Вы добавили '+lst.length+'-й домен');
}

function ShowDomains() {
	var resp = getCookie('domains_storage');
	if (resp != null) {
		lst = JSON.parse(resp);
		if (document.getElementById('domains-storage')) {
			if (lst.length > 0) {
				document.getElementById('domain-num').innerHTML = lst.length;
				var htm ='';
				for (var i = 0; i < lst.length; i++) {
					htm = htm + '<div class="order" id="mzone_' + i + '">' + lst[i] + '<div style="float:right;cursor: pointer; cursor: hand;" onclick="javascript:removeDomain(' + i + ', \'' + lst[i] + '\');">X</div></div>';
				}
				window.document.getElementById('cartmenu').innerHTML = htm;
				window.document.getElementById('cartmenu').className = 'order';
				window.document.getElementById('regbutton').className = '';
				Show('domains-storage');
			}
			else {
				Hide('cartmenu');
				Hide('regbutton');
				Hide('domains-storage');
			}
		}
	}
	else {
		Hide('domains-storage');
	}
}

function checkDomain (nam, list, command) {
	var cnt = 1;
	for (var k in list) {
		var t = setTimeout("insertFrame ('" + nam + "', '" + cnt + "', '" + command + "', '" + list[k] + "');", (cnt*1000));
		cnt++;
	}	
}

function insertFrame (nam, cnt, command, value) {
	var elem = nam + cnt;
	window.document.getElementById(elem).className = 'load';
	var domain = window.document.getElementById('domain').value;
	var inn = '<iframe src="/' + command + '?name=' + nam + '&number=' + cnt + '&domain=' + domain + '.' + value + '" width="0" height="0" frameborder="0" onload="ja' + 'vasc' + 'ript:Loadiframe(this, ' + cnt + ', \'' + nam + '\');"></iframe>'
	window.document.getElementById(nam + cnt).innerHTML = inn;
}

function buildOrder () {
	var domains = getCookie('domains_storage');

	if (window.document.getElementById('order')) {
		var htm ='';
		var lst = new Array();
		if (domains != null) {
			lst = JSON.parse(domains);
			for (var i = 0; i < lst.length; i++) {
				htm = htm + '<div class="order" id="dzone_' + i + '">' + lst[i] + '<div style="float:right;cursor: pointer; cursor: hand;" onclick="javascript:removeDomain(' + i + ', \'' + lst[i] + '\');">X</div></div>';
			}
			window.document.getElementById('order').innerHTML = htm;
		}
	}

	var resp = getCookie('fields_storage'); //  domains_storage
	var list = new Array();
	if (resp != null) {
		list = JSON.parse(resp);
		for (var i = 0; i < list.length; i++) {
			var tmp = new Array();
			tmp = list[i].split('|')
			if (tmp[0] != 'pass') {
				window.document.getElementById(tmp[0]).value = tmp[1];
			}
		}
		if (list.length < 1) {
			Hide('regbutton');
		}
	}

}

function SetError() {
	if (window.document.getElementById('error')) {
		var error = getCookie('error');
		var lst = new Array();
		if (error != null) {
			lst = error.split('|')
			var err = '';
			for (var i = 0; i < lst.length; i++) {
				lst[i] = lst[i].replace(/"/g,'');
				var tmp = new Array();
				tmp = lst[i].split('=')
				err = err + '<li class="order">' + tmp[1] + '</li>';
				if (window.document.getElementById(tmp[0])) {
					window.document.getElementById(tmp[0]).className = 'empty';
				}
			}
			if (window.document.getElementById('error')) {
				window.document.getElementById('error').innerHTML = err;
			}
		}
	}
}

function logOut() {
	DelCookie('session'); DelCookie('error'); DelCookie('error_forgot'); DelCookie('fields_storage'); window.location.assign("/");
}