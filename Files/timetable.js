var total_hours = 72;

function qel(id) {
    return q('#' + id)[0];
}

function unselect_do(elements) {
    for (var i = 0; i < elements.length; i++) {
        q('#' + elements[i].id).removeClass('select');
    }
}

function unselect(id) {
    unselect_do(q('.' + id));
    switch (id) {
        case 'hour':
            unselect_do(q('.halfhour'));
            select_halfhour();
            break;
        case 'halfhour':
            unselect_do(q('.hour'));
            break
        case 'day':
        case 'program':
            unselect_do(q('.program'));
            unselect_do(q('.day'));
            break;
    }
}

function select_week(e, nbr) {
    e.addClass = "select"
}

function select(id, bool) {
    var el = q('#' + id);
    if (bool) {
        el.addClass('select');
        return true;
    } else {
        el.removeClass('select');
        return false;
    }
}

function select_toggle(id) {
    var el = q('#' + id);
    return select(id, !el.hasClass('select'));
}

function select_hours_of_day(blocks) {
    unselect('halfhour');
    var halfhours = blocks_to_halfhours(blocks);
    for (var i = 0; i < halfhours.length; i++) {
        select_halfhour(null, halfhours[i]);
    }
}

function select_day(e, nbr) {
    //nbr = nbr ? nbr : parseInt(e.id[e.id.length - 1]);
    var day = 'day' + nbr;
    var prg = 'program' + nbr;
    select_toggle(day);
    if (select_toggle(prg)) {
        var blocks = q('#' + prg).getHtml();
        if (blocks != "---") {
            unselect('day');
            var programs = q('.program');
            for (var i = 0; i < programs.length; i++) {
                if (q('#' + programs[i].id).getHtml() == blocks) {
                    select_toggle('day' + i);
                    select_toggle('program' + i);
                }
            }
            select_hours_of_day(blocks);
        } else {
            var programs = q('.program').filter('.select');
            for (var i = 0; i < programs.length; i++) {
                if (q('#' + programs[i].id).getHtml() != "---") {
                    unselect('day');
                    select_day(e, nbr);
                }
            }
            unselect('hour');
        }
    } else {
        // If we have a multiple selection with hours and we click again on a day,
        // this day gets highlighted alone
        var other_days = q('.day').filter('.select');
        var other_hours = q('.hour').filter('.select');
        if (other_days.length * other_hours.length > 0) {
            unselect('day');
            select(day, true);
            select(prg, true);
            select_hours_of_day(q('#program' + nbr).getHtml());
        }else {
            unselect('hour');
        }
    }
}

function select_program(e, nbr) {
    select_day(e, nbr)
}

function halfhour_to_hour(halfhour) {
    return Math.floor(halfhour / 2) + ":" +
        ( ( halfhour % 2 ) ? "30" : "00" );
}

function hour_to_halfhour(hour) {
    var h = hour.split(":");
    return parseInt(h[0]) * 2 + (h[1] == "00" ? 0 : 1);
}

function halfhour_range(start, end) {
    return halfhour_to_hour(start) + " - " +
        halfhour_to_hour(end);
}

function halfhours_to_blocks(halfhours) {
    var blocks = [];
    var start = halfhours[0], end = start;
    for (var i = 1; i < halfhours.length; i++) {
        if (halfhours[i] > end + 1) {
            blocks.push(halfhour_range(start, end + 1));
            start = halfhours[i];
        }
        end = halfhours[i];
    }
    if (start != undefined) {
        blocks.push(halfhour_range(start, end + 1));
    }
    return blocks;
}

function blocks_to_halfhours(blocks_html) {
    var halfhours = [];
    var blocks = blocks_html ? blocks_html.split('<br>') : [];
    for (var i = 0; i < blocks.length; i++) {
        var fromto = blocks[i].split(" - ");
        var start = hour_to_halfhour(fromto.shift()),
            end = hour_to_halfhour(fromto.shift());
        for (var j = start; j < end; j++) {
            halfhours.push(j);
        }
    }
    return halfhours;
}

function select_hour(e, nbr) {
    var bool = select_toggle(e.id);
    select_halfhour(null, nbr * 2, bool);
    select_halfhour(null, nbr * 2 + 1, bool);
}

function select_halfhour(e, nbr, bool) {
    if (nbr || e) {
        if (!e) {
            e = qel('halfhour' + nbr);
        } else if (!nbr) {
            nbr = parseInt(e.id.replace(/halfhour/, ''));
        }
        if (bool != undefined) {
            select('halfhour' + nbr, bool);
        } else {
            bool = select_toggle(e.id);
        }
        var hour = Math.floor(nbr / 2);
        if (bool) {
            bool &= q('#halfhour' + (nbr ^ 1)).hasClass("select");
        }
        select('hour' + hour, bool);
    }

    var halfhours_el = q('.halfhour').filter('.select');
    var halfhours = [];
    for (var i = 0; i < halfhours_el.length; i++) {
        halfhours.push(parseInt(halfhours_el[i].id.replace(/halfhour/, '')));
    }
    var blocks = halfhours_to_blocks(halfhours).join("<br>");
    if (blocks == "") {
        blocks = "---";
    }

    var prg_el = q('.program').filter('.select');
    for (var i = 0; i < prg_el.length; i++) {
        q('#' + prg_el[i].id).setHtml(blocks);
    }
}

function create_td(name, align, nbr, total, str, sp) {
    var span = sp ? sp : 1;
    return "<td align='" + align + "' class='" + name + "' id='" + name + nbr +
        "' " + " onclick='select_" + name + "(this," + nbr + ")' " +
        "width='" + 100 / total + "%' colspan='" + span + "'>" + str + "</td>";
}

function add_tr(id, s) {
    var el = q('#tr_' + id);
    var str = s ? s : "";
    el.setHtml("<td onclick=\"unselect('" + id.replace(/s$/, '') + "');\">" + id + "</td>" +
        "<td><table border='1' width='100%'>" +
        "<tr id='" + id + "'></tr>" + str +
        "</table></td >");
}

function add_weeks(nbr) {
    add_tr('weeks');
    var weeks = "";
    for (var i = 1; i <= nbr; i++) {
        weeks += create_td('week', 'center', i, nbr, i);
    }
    q('#weeks').setHtml(weeks);
}

function add_days() {
    add_tr('days', "<tr id='programs'></tr>");
    var days_str = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];
    var days = "", programs = "";
    for (var i = 0; i < 7; i++) {
        days += create_td('day', 'center', i, 7, days_str[i]);
        programs += create_td('program', 'center', i, 7, "---");
    }
    q('#days').setHtml(days);
    q('#programs').setHtml(programs);
}

function add_hours() {
    add_tr('hours', "<tr id='halfhours'></tr>");
    var hours = "", halfhours = "";
    for (var i = 6; i <= 20; i++) {
        hours += create_td('hour', 'center', i, 15, i, 2);
        halfhours += create_td('halfhour', 'center', i * 2, 30, ":00");
        halfhours += create_td('halfhour', 'center', i * 2 + 1, 30, ":30");
    }
    q('#hours').setHtml(hours);
    q('#halfhours').setHtml(halfhours);
}
