--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"
require "prefs_utils"
require "blacklist_utils"
local template = require "template_utils"

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/scripts/lua/pro/?.lua;" .. package.path
end

sendHTTPContentTypeHeader('text/html')

local show_advanced_prefs = false
local alerts_disabled = false

if(haveAdminPrivileges()) then
   if(_POST["flush_alerts_data"] ~= nil) then
    require "alert_utils"
    flushAlertsData()
   end

   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

   active_page = "admin"
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

   prefs = ntop.getPrefs()

   print [[
	    <h2>Runtime Preferences</h2>
      ]]

   if(false) then
      io.write("------- SERVER ----------------\n")
      tprint(_SERVER)
      io.write("-------- GET ---------------\n")
      tprint(_GET)
      io.write("-------- POST ---------------\n")
      tprint(_POST)
      io.write("-----------------------\n")
   end

   if toboolean(_POST["show_advanced_prefs"]) ~= nil then
      ntop.setPref(show_advanced_prefs_key, _POST["show_advanced_prefs"])
      show_advanced_prefs = toboolean(_POST["show_advanced_prefs"])
      notifyNtopng(show_advanced_prefs_key, _POST["show_advanced_prefs"])
   else
      show_advanced_prefs = toboolean(ntop.getPref(show_advanced_prefs_key))
      if isEmptyString(show_advanced_prefs) then show_advanced_prefs = false end
   end

   if hasAlertsDisabled() then
    alerts_disabled = true
   end

local subpage_active, tab = prefsGetActiveSubpage(show_advanced_prefs, _GET["tab"])

-- ================================================================================

function printInterfaces()
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.dynamic_network_interfaces")..'</th></tr>')

  local labels = {i18n("prefs.none"),
		  i18n("prefs.vlan"),
		  i18n("prefs.probe_ip_address"),
		  i18n("prefs.ingress_flow_interface"),
		  i18n("prefs.ingress_vrf_id")}
  local values = {"none",
		  "vlan",
		  "probe_ip",
		  "ingress_iface_idx",
		  "ingress_vrf_id"}

  local elementToSwitch = {}
  local showElementArray = { true, false, false }
  local javascriptAfterSwitch = "";

  retVal = multipleTableButtonPrefs(subpage_active.entries["dynamic_interfaces_creation"].title,
				    subpage_active.entries["dynamic_interfaces_creation"].description.."<p><b>"..i18n("notes").."</b><ul>"..
				    "<li>"..i18n("prefs.dynamic_interfaces_creation_note_0").."</li>"..
				    "<li>"..i18n("prefs.dynamic_interfaces_creation_note_1").."</li>"..
				    "<li>"..i18n("prefs.dynamic_interfaces_creation_note_2").."</li></ul>",
				    labels, values, "none", "primary", "disaggregation_criterion", "ntopng.prefs.dynamic_flow_collection_mode", nil,
				    elementToSwitch, showElementArray, javascriptAfterSwitch)

  print('<tr><th colspan=2 class="info">'..i18n("prefs.zmq_interfaces")..'</th></tr>')

  prefsToggleButton({
	field = "toggle_dst_with_post_nat_dst",
	default = "0",
	pref = "override_dst_with_post_nat_dst",
  })

  prefsToggleButton({
	field = "toggle_src_with_post_nat_src",
	default = "0",
	pref = "override_src_with_post_nat_src",
  })

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printAlerts()
  print(
    template.gen("modal_confirm_dialog.html", {
      dialog={
        id      = "flushAlertsData",
        action  = "flushAlertsData()",
        title   = i18n("show_alerts.reset_alert_database"),
        message = i18n("show_alerts.reset_alert_database_message") .. "?",
        confirm = i18n("show_alerts.flush_data"),
        confirm_button = "btn-danger",
      }
    })
  )

  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("show_alerts.alerts")..'</th></tr>')

 if ntop.getPref("ntopng.prefs.disable_alerts_generation") == "1" then
      showElements = true
  else
      showElements = false
  end

 local elementToSwitch = { "max_num_alerts_per_entity", "max_num_flow_alerts", "row_toggle_alert_probing",
  "row_toggle_malware_probing", "row_toggle_alert_syslog", "row_toggle_mysql_check_open_files_limit",
  "row_toggle_flow_alerts_iface", "row_alerts_retention_header", "row_alerts_security_header",
  "row_toggle_ssl_alerts", "row_toggle_dns_alerts"}

  prefsToggleButton({
    field = "disable_alerts_generation",
    default = "0",
    to_switch = elementToSwitch,
    on_value = "0",     -- On  means alerts enabled and thus disable_alerts_generation == 0
    off_value = "1",    -- Off for enabled alerts implies 1 for disable_alerts_generation
  })

  if ntop.getPrefs().are_alerts_enabled == true then
     showElements = true
  else
     showElements = false
  end

  prefsToggleButton({
    field = "toggle_flow_alerts_iface",
    default = "0",
    pref = "alerts.dump_alerts_when_iface_is_alerted",
    hidden = not showElements,
  })

  prefsToggleButton({
    field = "toggle_mysql_check_open_files_limit",
    default = "1",
    pref = "alerts.mysql_check_open_files_limit",
    hidden = not showElements or subpage_active.entries["toggle_mysql_check_open_files_limit"].hidden,
  })

  print('<tr id="row_alerts_security_header" ')
  if (showElements == false) then print(' style="display:none;"') end
  print('><th colspan=2 class="info">'..i18n("prefs.security_alerts")..'</th></tr>')

  prefsToggleButton({
    field = "toggle_alert_probing",
    pref = "probing_alerts",
    default = "0",
    hidden = not showElements,
  })

  prefsToggleButton({
    field = "toggle_ssl_alerts",
    pref = "ssl_alerts",
    default = "0",
    hidden = not showElements,
  })

  prefsToggleButton({
    field = "toggle_dns_alerts",
    pref = "dns_alerts",
    default = "0",
    hidden = not showElements,
  })

  prefsToggleButton({
    field = "toggle_malware_probing",
    pref = "host_blacklist",
    default = "1",
    hidden = not showElements,
  })

  print('<tr id="row_alerts_retention_header" ')
  if (showElements == false) then print(' style="display:none;"') end
  print('><th colspan=2 class="info">'..i18n("prefs.alerts_retention")..'</th></tr>')

  prefsInputFieldPrefs(subpage_active.entries["max_num_alerts_per_entity"].title, subpage_active.entries["max_num_alerts_per_entity"].description,
        "ntopng.prefs.", "max_num_alerts_per_entity", prefs.max_num_alerts_per_entity, "number", showElements, false, nil, {min=1, --[[ TODO check min/max ]]})

  prefsInputFieldPrefs(subpage_active.entries["max_num_flow_alerts"].title, subpage_active.entries["max_num_flow_alerts"].description,
        "ntopng.prefs.", "max_num_flow_alerts", prefs.max_num_flow_alerts, "number", showElements, false, nil, {min=1, --[[ TODO check min/max ]]})

  print('<tr><th colspan=2 style="text-align:right;">')
  print('<button class="btn btn-default" type="button" onclick="$(\'#flushAlertsData\').modal(\'show\');" style="width:230px; float:left;">'..i18n("show_alerts.reset_alert_database")..'</button>')
  print('<button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button>')
  print('</th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>

  <script>
    function flushAlertsData() {
      var params = {};

      params.flush_alerts_data = "";
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

      var form = paramsToForm('<form method="post"></form>', params);
      form.appendTo('body').submit();
    }
  </script>
  ]]
end

-- ================================================================================

function printExternalAlertsReport()
  if alerts_disabled then return end

  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.internal_log")..'</th></tr>')

  local showElements = true

  prefsToggleButton({
    field = "toggle_alert_syslog",
    pref = "alerts_syslog",
    default = "0"
  })

   print('<tr><th colspan=2 class="info"><i class="fa fa-slack" aria-hidden="true"></i> '..i18n('prefs.slack_integration')..'</th></tr>')

   local elementToSwitchSlack = {"row_slack_notification_severity_preference", "sender_username", "slack_webhook"}

  prefsToggleButton({
    field = "toggle_slack_notification",
    pref = "alerts.slack_notifications_enabled",
    default = "0",
    disabled = showElements==false,
    to_switch = elementToSwitchSlack,
  })

  local showSlackNotificationPrefs = false
  if ntop.getPref("ntopng.prefs.alerts.slack_notifications_enabled") == "1" then
     showSlackNotificationPrefs = true
  else
     showSlackNotificationPrefs = false
  end

  local labels = {i18n("prefs.errors"), i18n("prefs.errors_and_warnings"), i18n("prefs.all")}
  local values = {"only_errors","errors_and_warnings","all_alerts"}

  local retVal = multipleTableButtonPrefs(subpage_active.entries["slack_notification_severity_preference"].title, subpage_active.entries["slack_notification_severity_preference"].description,
               labels, values, "only_errors", "primary", "slack_notification_severity_preference",
	       "ntopng.prefs.alerts.slack_alert_severity", nil, nil, nil,  nil, showElements and showSlackNotificationPrefs)

  prefsInputFieldPrefs(subpage_active.entries["sender_username"].title, subpage_active.entries["sender_username"].description,
           "ntopng.prefs.alerts.", "sender_username",
		       "ntopng Webhook", nil, showElements and showSlackNotificationPrefs, false, nil, {attributes={spellcheck="false"}, required=true})

  prefsInputFieldPrefs(subpage_active.entries["slack_webhook"].title, subpage_active.entries["slack_webhook"].description,
		       "ntopng.prefs.alerts.", "slack_webhook",
		       "", nil, showElements and showSlackNotificationPrefs, true, true, {attributes={spellcheck="false"}, style={width="43em"}, required=true, pattern=getURLPattern()})

  if(ntop.isPro() and hasNagiosSupport()) then
    print('<tr><th colspan=2 class="info">'..i18n("prefs.nagios_integration")..'</th></tr>')

    local alertsEnabled = showElements

    local elementToSwitch = {"nagios_nsca_host","nagios_nsca_port","nagios_send_nsca_executable","nagios_send_nsca_config","nagios_host_name","nagios_service_name"}

    prefsToggleButton({
      field = "toggle_alert_nagios",
      pref = "alerts_nagios",
      default = "0",
      disabled = alertsEnabled==false,
      to_switch = elementToSwitch,
    })

    if ntop.getPref("ntopng.prefs.alerts_nagios") == "0" then
      showElements = false
    end
    showElements = alertsEnabled and showElements

    prefsInputFieldPrefs(subpage_active.entries["nagios_nsca_host"].title, subpage_active.entries["nagios_nsca_host"].description, "ntopng.prefs.", "nagios_nsca_host", prefs.nagios_nsca_host, nil, showElements, false)
    prefsInputFieldPrefs(subpage_active.entries["nagios_nsca_port"].title, subpage_active.entries["nagios_nsca_port"].description, "ntopng.prefs.", "nagios_nsca_port", prefs.nagios_nsca_port, "number", showElements, false, nil, {min=1, max=65535})
    prefsInputFieldPrefs(subpage_active.entries["nagios_send_nsca_executable"].title, subpage_active.entries["nagios_send_nsca_executable"].description, "ntopng.prefs.", "nagios_send_nsca_executable", prefs.nagios_send_nsca_executable, nil, showElements, false)
    prefsInputFieldPrefs(subpage_active.entries["nagios_send_nsca_config"].title, subpage_active.entries["nagios_send_nsca_config"].description, "ntopng.prefs.", "nagios_send_nsca_config", prefs.nagios_send_nsca_conf, nil, showElements, false)
    prefsInputFieldPrefs(subpage_active.entries["nagios_host_name"].title, subpage_active.entries["nagios_host_name"].description, "ntopng.prefs.", "nagios_host_name", prefs.nagios_host_name, nil, showElements, false)
    prefsInputFieldPrefs(subpage_active.entries["nagios_service_name"].title, subpage_active.entries["nagios_service_name"].description, "ntopng.prefs.", "nagios_service_name", prefs.nagios_service_name, nil, showElements)
  end
  
  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printProtocolPrefs()
  print('<form method="post">')

  print('<table class="table">')

  print('<tr><th colspan=2 class="info">HTTP</th></tr>')

  prefsToggleButton({
    field = "toggle_top_sites",
    pref = "host_top_sites_creation",
    default = "0",
  })

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')

  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printBridgingPrefs()
  if not isAdministrator() then
    return
  end

  local show
  local label

  if isCaptivePortalSupported(nil, prefs, true --[[ skip interface check ]]) then
     show = true
     label = ""
  else
     show = false
     label = "<p>"..i18n("prefs.captive_portal_disabled_message").."</p>"
  end

  print('<form method="post">')

  print('<table class="table">')

  if show_advanced_prefs then
    print('<tr><th colspan=2 class="info">'..i18n("traffic_policy")..'</th></tr>')

    prefsToggleButton({
      field = "toggle_shaping_directions",
      pref = "split_shaping_directions",
      default = "0",
    })

    local labels = {
      i18n("prefs.per_protocol"),
      i18n("prefs.per_category"),
      i18n("prefs.both"),
    }

    local values = {
      "per_protocol",
      "per_category",
      "both",
    }

    multipleTableButtonPrefs(subpage_active.entries["policy_target_type"].title,
				    subpage_active.entries["policy_target_type"].description,
				    labels, values,
				    "per_category",
				    "primary",
				    "bridging_policy_target_type",
				    "ntopng.prefs.bridging_policy_target_type")
  end

  print('<tr><th colspan=2 class="info">'..i18n("prefs.dns")..'</th></tr>')

  prefsInputFieldPrefs(subpage_active.entries["safe_search_dns"].title, subpage_active.entries["safe_search_dns"].description,
        "ntopng.prefs.", "safe_search_dns", prefs.safe_search_dns, nil, true, false, nil, {required=true, pattern=getIPv4Pattern()})
  prefsInputFieldPrefs(subpage_active.entries["global_dns"].title, subpage_active.entries["global_dns"].description,
        "ntopng.prefs.", "global_dns", prefs.global_dns, nil, true, false, nil, {pattern=getIPv4Pattern()})
  prefsInputFieldPrefs(subpage_active.entries["secondary_dns"].title, subpage_active.entries["secondary_dns"].description,
        "ntopng.prefs.", "secondary_dns", prefs.secondary_dns, nil, true, false, nil, {pattern=getIPv4Pattern()})

  prefsInformativeField(subpage_active.entries["featured_dns"].title, subpage_active.entries["featured_dns"].description..[[<br><br>
        <table class='table table-bordered table-condensed small'>
          <tr><th>]]..i18n("prefs.dns_service")..[[</th><th>]]..i18n("prefs.primary_dns")..[[</th><th>]]..i18n("prefs.secondary_dns")..[[</th></tr>
          <tr><td><a href="https://www.comodo.com/secure-dns/">Comodo Secure DNS</a></td><td>8.26.56.26</td><td>8.20.247.20</td></tr>
          <tr><td><a href="http://dyn.com/labs/dyn-internet-guide/">Dyn Internet Guide</a><td>216.146.35.35</td><td>216.146.36.36</td></tr>
          <tr><td><a href="http://www.fooldns.com/fooldns-community/english-version/">FoolDNS</a></td><td>87.118.111.215</td><td>213.187.11.62</td></tr>
          <tr><td><a href="http://members.greentm.co.uk/">GreenTeam Internet</a></td><td>81.218.119.11</td><td>209.88.198.133</td></tr>
          <tr><td><a href="https://www.opendns.com/">OpenDNS</a></td><td>208.67.222.222</td><td>208.67.220.220</td></tr>
          <tr><td><a href="https://www.opendns.com/setupguide/?url=familyshield">OpenDNS - FamilyShield</a></td><td>208.67.222.123</td><td>208.67.220.123</td></tr>
          <tr><td><a href="https://dns.norton.com/">Norton ConnectSafe - Security</a></td><td>199.85.126.10</td><td>199.85.127.10</td></tr>
          <tr><td><a href="https://dns.norton.com/">Norton ConnectSafe - Security + Pornography</a></td><td>199.85.126.20</td><td>199.85.127.20</td></tr>
          <tr><td><a href="https://dns.norton.com/">Norton ConnectSafe - Security + Other</a></td><td>199.85.126.30</td><td>199.85.127.30</td></tr>
        </table>
        ]], true)

  print('<tr><th colspan=2 class="info">'..i18n("prefs.user_authentication")..'</th></tr>')

  local captivePortalElementsToSwitch = {"redirection_url"}
  prefsToggleButton({
    field = "toggle_captive_portal",
    pref = "enable_captive_portal",
    default = "0",
    disabled = not(show),
    to_switch = captivePortalElementsToSwitch,
  })

  local to_show = (ntop.getPref("ntopng.prefs.enable_captive_portal") == "1")
  prefsInputFieldPrefs(subpage_active.entries["captive_portal_url"].title, subpage_active.entries["captive_portal_url"].description,
        "ntopng.prefs.", "redirection_url", prefs.redirection_url, nil, to_show, false, nil, {pattern=getURLPattern()})
  
  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')

  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printNbox()
  print('<form method="post">')
  print('<table class="table">')

  print('<tr><th colspan=2 class="info">'..i18n("prefs.nbox_integration")..'</th></tr>')

  local elementToSwitch = {"nbox_user","nbox_password"}

  prefsToggleButton({
    field = "toggle_nbox_integration",
    default = "0",
    pref = "nbox_integration",
    to_switch = elementToSwitch,
  })

  if ntop.getPref("ntopng.prefs.nbox_integration") == "1" then
    showElements = true
  else
    showElements = false
  end

  prefsInputFieldPrefs(subpage_active.entries["nbox_user"].title, subpage_active.entries["nbox_user"].description, "ntopng.prefs.", "nbox_user", "nbox", nil, showElements, false)
  prefsInputFieldPrefs(subpage_active.entries["nbox_password"].title, subpage_active.entries["nbox_password"].description, "ntopng.prefs.", "nbox_password", "nbox", "password", showElements, false)

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')

  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printNetworkDiscovery()
   print('<form method="post">')
   print('<table class="table">')

   print('<tr><th colspan=2 class="info">'..i18n("prefs.network_discovery")..'</th></tr>')

   local elementToSwitch = {"network_discovery_interval"}

   prefsToggleButton({
    field = "toggle_network_discovery",
    default = "0",
    pref = "is_network_discovery_enabled",
    to_switch = elementToSwitch,
  })

   local showNetworkDiscoveryInterval = false
   if ntop.getPref("ntopng.prefs.is_network_discovery_enabled") == "1" then
      showNetworkDiscoveryInterval = true
   end

   local interval = ntop.getPref("ntopng.prefs.network_discovery_interval")

   if isEmptyString(interval) then -- set a default value
      interval = 15 * 60 -- 15 minutes
      ntop.setPref("ntopng.prefs.network_discovery_interval", tostring(interval))
   end

   prefsInputFieldPrefs(subpage_active.entries["network_discovery_interval"].title, subpage_active.entries["network_discovery_interval"].description,
    "ntopng.prefs.", "network_discovery_interval", interval, "number", showNetworkDiscoveryInterval, nil, nil, {min=60 * 15, tformat="mhd"})

   print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')

   print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
    </form>]]
end

-- ================================================================================

function printMisc()
  print('<form method="post">')
  print('<table class="table">')

  print('<tr><th colspan=2 class="info">'..i18n("prefs.web_user_interface")..'</th></tr>')
  if prefs.is_autologout_enabled == true then
    prefsToggleButton({
      field = "toggle_autologout",
      default = "1",
      pref = "is_autologon_enabled",
    })
  end

  prefsInputFieldPrefs(subpage_active.entries["max_ui_strlen"].title, subpage_active.entries["max_ui_strlen"].description,
		       "ntopng.prefs.", "max_ui_strlen", prefs.max_ui_strlen, "number", nil, nil, nil, {min=3, max=128})

  prefsInputFieldPrefs(subpage_active.entries["google_apis_browser_key"].title, subpage_active.entries["google_apis_browser_key"].description,
		       "ntopng.prefs.",
		       "google_apis_browser_key",
		       "", false, nil, nil, nil, {style={width="25em;"}, attributes={spellcheck="false"} --[[ Note: Google API keys can vary in format ]] })

  -- ######################

  print('<tr><th colspan=2 class="info">'..i18n("prefs.report")..'</th></tr>')

  local t_labels = {i18n("bytes"), i18n("packets")}
  local t_values = {"bps", "pps"}

  multipleTableButtonPrefs(subpage_active.entries["toggle_thpt_content"].title, subpage_active.entries["toggle_thpt_content"].description,
			   t_labels, t_values, "bps", "primary", "toggle_thpt_content", "ntopng.prefs.thpt_content")

  -- ######################

  if ntop.isPro() then
     t_labels = {i18n("topk_heuristic.precision.disabled"),
		 i18n("topk_heuristic.precision.more_accurate"),
		 i18n("topk_heuristic.precision.less_accurate"),
		 i18n("topk_heuristic.precision.aggressive")}
     t_values = {"disabled", "more_accurate", "accurate", "aggressive"}

     multipleTableButtonPrefs(subpage_active.entries["topk_heuristic_precision"].title,
			      subpage_active.entries["topk_heuristic_precision"].description,
			      t_labels, t_values, "more_accurate", "primary", "topk_heuristic_precision",
			      "ntopng.prefs.topk_heuristic_precision")
  end

  -- ######################

  if(haveAdminPrivileges()) then
     print('<tr><th colspan=2 class="info">'..i18n("prefs.host_mask")..'</th></tr>')
     
     local h_labels = {i18n("prefs.no_host_mask"), i18n("prefs.local_host_mask"), i18n("prefs.remote_host_mask")}
     local h_values = {"0", "1", "2"}
     
     multipleTableButtonPrefs(subpage_active.entries["toggle_host_mask"].title,
			      subpage_active.entries["toggle_host_mask"].description,
			      h_labels, h_values, "0", "primary", "toggle_host_mask", "ntopng.prefs.host_mask")
  end

  -- #####################

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" onclick="return save_button_users();" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
    </form>]]

end

-- ================================================================================

function printAuthentication()
  if not ntop.isPro() then return end

  print('<form method="post">')
  print('<table class="table">')

  print('<tr><th colspan=2 class="info">'..i18n("prefs.authentication")..'</th></tr>')
  local labels = {i18n("prefs.local"), i18n("prefs.ldap"), i18n("prefs.ldap_local")}
  local values = {"local","ldap","ldap_local"}
  local elementToSwitch = {"row_multiple_ldap_account_type", "row_toggle_ldap_anonymous_bind","server","bind_dn", "bind_pwd", "ldap_server_address", "search_path", "user_group", "admin_group"}
  local showElementArray = {false, true, true}
  local javascriptAfterSwitch = "";
  javascriptAfterSwitch = javascriptAfterSwitch.."  if($(\"#id-toggle-multiple_ldap_authentication\").val() != \"local\"  ) {\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."    if($(\"#toggle_ldap_anonymous_bind_input\").val() == \"0\") {\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#bind_dn\").css(\"display\",\"table-row\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#bind_pwd\").css(\"display\",\"table-row\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."    } else {\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#bind_dn\").css(\"display\",\"none\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#bind_pwd\").css(\"display\",\"none\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."    }\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."  }\n"
  local retVal = multipleTableButtonPrefs(subpage_active.entries["multiple_ldap_authentication"].title,
           subpage_active.entries["multiple_ldap_authentication"].description,
           labels, values, "local", "primary", "multiple_ldap_authentication", "ntopng.prefs.auth_type", nil,
           elementToSwitch, showElementArray, javascriptAfterSwitch)

  local showElements = true;
  if ntop.getPref("ntopng.prefs.auth_type") == "local" then
  showElements = false
  end

  local labels_account = {i18n("prefs.posix"), i18n("prefs.samaccount")}
  local values_account = {"posix","samaccount"}
  multipleTableButtonPrefs(subpage_active.entries["multiple_ldap_account_type"].title, subpage_active.entries["multiple_ldap_account_type"].description,
        labels_account, values_account, "posix", "primary", "multiple_ldap_account_type", "ntopng.prefs.ldap.account_type", nil, nil, nil, nil, showElements)

  prefsInputFieldPrefs(subpage_active.entries["ldap_server_address"].title, subpage_active.entries["ldap_server_address"].description,
        "ntopng.prefs.ldap", "ldap_server_address", "ldap://localhost:389", nil, showElements, true, true, {attributes={pattern="ldap(s)?://[0-9.\\-A-Za-z]+(:[0-9]+)?", spellcheck="false", required="required"}})

  local elementToSwitchBind = {"bind_dn","bind_pwd"}
  prefsToggleButton({
      field = "toggle_ldap_anonymous_bind",
      default = "1",
      pref = "ldap.anonymous_bind",
      to_switch = elementToSwitchBind,
      reverse_switch = true,
      hidden = not showElements,
    })

  local showEnabledAnonymousBind = false
    if ntop.getPref("ntopng.prefs.ldap.anonymous_bind") == "0" then
  showEnabledAnonymousBind = true
  end
  local showElementsBind = showElements
  if showElements == true then
    showElementsBind = showEnabledAnonymousBind
  end
  -- These two fields are necessary to prevent chrome from filling in LDAP username and password with saved credentials
  -- Chrome, in fact, ignores the autocomplete=off on the input field. The input fill-in triggers un-necessary are-you-sure leave message
  print('<input style="display:none;" type="text" name="_" data-ays-ignore="true" />')
  print('<input style="display:none;" type="password" name="__" data-ays-ignore="true" />')
  --
  prefsInputFieldPrefs(subpage_active.entries["bind_dn"].title, subpage_active.entries["bind_dn"].description .. "\"CN=ntop_users,DC=ntop,DC=org,DC=local\".", "ntopng.prefs.ldap", "bind_dn", "", nil, showElementsBind, true, false, {attributes={spellcheck="false"}})
  prefsInputFieldPrefs(subpage_active.entries["bind_pwd"].title, subpage_active.entries["bind_pwd"].description, "ntopng.prefs.ldap", "bind_pwd", "", "password", showElementsBind, true, false)

  prefsInputFieldPrefs(subpage_active.entries["search_path"].title, subpage_active.entries["search_path"].description, "ntopng.prefs.ldap", "search_path", "", "text", showElements, nil, nil, {attributes={spellcheck="false"}})
  prefsInputFieldPrefs(subpage_active.entries["user_group"].title, subpage_active.entries["user_group"].description, "ntopng.prefs.ldap", "user_group", "", "text", showElements, nil, nil, {attributes={spellcheck="false"}})
  prefsInputFieldPrefs(subpage_active.entries["admin_group"].title, subpage_active.entries["admin_group"].description, "ntopng.prefs.ldap", "admin_group", "", "text", showElements, nil, nil, {attributes={spellcheck="false"}})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" onclick="return save_button_users();" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />]]
  print('</form>')
end

-- ================================================================================

function printInMemory()
  print('<form id="localRemoteTimeoutForm" method="post">')

  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.local_hosts_cache_settings")..'</th></tr>')

  prefsToggleButton({
    field = "toggle_local_host_cache_enabled",
    default = "1",
    pref = "is_local_host_cache_enabled",
    to_switch = {"local_host_cache_duration"},
  })

  local showLocalHostCacheInterval = false
  if ntop.getPref("ntopng.prefs.is_local_host_cache_enabled") == "1" then
    showLocalHostCacheInterval = true
  end

  prefsInputFieldPrefs(subpage_active.entries["local_host_cache_duration"].title, subpage_active.entries["local_host_cache_duration"].description,
    "ntopng.prefs.","local_host_cache_duration", prefs.local_host_cache_duration, "number", showLocalHostCacheInterval, nil, nil, {min=60, tformat="mhd"})

  prefsToggleButton({
    field = "toggle_active_local_host_cache_enabled",
    default = "0",
    pref = "is_active_local_host_cache_enabled",
    to_switch = {"active_local_host_cache_interval"},
  })

  local showActiveLocalHostCacheInterval = false
  if ntop.getPref("ntopng.prefs.is_active_local_host_cache_enabled") == "1" then
    showActiveLocalHostCacheInterval = true
  end

  prefsInputFieldPrefs(subpage_active.entries["active_local_host_cache_interval"].title, subpage_active.entries["active_local_host_cache_interval"].description,
    "ntopng.prefs.", "active_local_host_cache_interval", prefs.active_local_host_cache_interval or 3600, "number", showActiveLocalHostCacheInterval, nil, nil, {min=60, tformat="mhd"})

  print('</table>')
  
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.idle_timeout_settings")..'</th></tr>')
  prefsInputFieldPrefs(subpage_active.entries["local_host_max_idle"].title, subpage_active.entries["local_host_max_idle"].description,
      "ntopng.prefs.","local_host_max_idle", prefs.local_host_max_idle, "number", nil, nil, nil, {min=1, max=86400, tformat="smh", attributes={["data-localremotetimeout"]="localremotetimeout"}})
  prefsInputFieldPrefs(subpage_active.entries["non_local_host_max_idle"].title, subpage_active.entries["non_local_host_max_idle"].description,
      "ntopng.prefs.", "non_local_host_max_idle", prefs.non_local_host_max_idle, "number", nil, nil, nil, {min=1, max=86400, tformat="smh"})
  prefsInputFieldPrefs(subpage_active.entries["flow_max_idle"].title, subpage_active.entries["flow_max_idle"].description,
      "ntopng.prefs.", "flow_max_idle", prefs.flow_max_idle, "number", nil, nil, nil, {min=1, max=86400, tformat="smh"})

  prefsInputFieldPrefs(subpage_active.entries["housekeeping_frequency"].title, subpage_active.entries["housekeeping_frequency"].description,
      "ntopng.prefs.", "housekeeping_frequency", prefs.housekeeping_frequency, "number", nil, nil, nil, {min=1, max=60})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>

  <script>
    function localRemoteTimeoutValidator() {
      var form = $("#localRemoteTimeoutForm");
      var local_timeout = resol_selector_get_raw($("input[name='local_host_max_idle']", form));
      var remote_timeout = resol_selector_get_raw($("input[name='non_local_host_max_idle']", form));

      if ((local_timeout != null) && (remote_timeout != null)) {
        if (local_timeout < remote_timeout)
          return false;
      }

      return true;
    }
  
    var idleFormValidatorOptions = {
      disable: true,
      custom: {
         localremotetimeout: localRemoteTimeoutValidator,
      }, errors: {
         localremotetimeout: "Cannot be less then Remote Host Idle Timeout",
      }
   }

   $("#localRemoteTimeoutForm")
      .validator(idleFormValidatorOptions);

   /* Retrigger the validation every second to clear outdated errors */
   setInterval(function() {
      $("#localRemoteTimeoutForm").data("bs.validator").validate();
    }, 1000);
  </script>
  ]]
end

-- ================================================================================

function printStatsTimeseries()
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n('prefs.interfaces_timeseries')..'</th></tr>')

  -- TODO: make also per-category interface RRDs
  local l7_rrd_labels = {i18n("prefs.none"),
		  i18n("prefs.per_protocol"),
		  i18n("prefs.per_category"),
		  i18n("prefs.both")
                  }
  local l7_rrd_values = {"none",
		  "per_protocol",
		  "per_category",
		  "both"}

  local elementToSwitch = { }
  local showElementArray = nil -- { true, false, false }
  local javascriptAfterSwitch = "";

  prefsToggleButton({
	field = "toggle_interface_traffic_rrd_creation",
	default = "1",
	pref = "interface_rrd_creation",
	to_switch = {"row_interfaces_ndpi_timeseries_creation"},
  })

  local showElement = ntop.getPref("ntopng.prefs.interface_rrd_creation") == "1"

  retVal = multipleTableButtonPrefs(subpage_active.entries["toggle_ndpi_timeseries_creation"].title,
				    subpage_active.entries["toggle_ndpi_timeseries_creation"].description,
				    l7_rrd_labels, l7_rrd_values,
				    "per_protocol",
				    "primary",
				    "interfaces_ndpi_timeseries_creation",
				    "ntopng.prefs.interface_ndpi_timeseries_creation", nil,
				    elementToSwitch, showElementArray, javascriptAfterSwitch, showElement)


  print('<tr><th colspan=2 class="info">'..i18n('prefs.local_hosts_timeseries')..'</th></tr>')

  prefsToggleButton({
    field = "toggle_local_hosts_traffic_rrd_creation",
    default = "1",
    pref = "host_rrd_creation",
    to_switch = {"row_hosts_ndpi_timeseries_creation"},
  })

  local showElement = ntop.getPref("ntopng.prefs.host_rrd_creation") == "1"

  retVal = multipleTableButtonPrefs(subpage_active.entries["toggle_ndpi_timeseries_creation"].title,
				    subpage_active.entries["toggle_ndpi_timeseries_creation"].description,
				    l7_rrd_labels, l7_rrd_values,
				    "none",
				    "primary",
				    "hosts_ndpi_timeseries_creation",
				    "ntopng.prefs.host_ndpi_timeseries_creation", nil,
				    elementToSwitch, showElementArray, javascriptAfterSwitch, showElement)

  print('<tr><th colspan=2 class="info">'..i18n('prefs.l2_devices_timeseries')..'</th></tr>')

  prefsToggleButton({
    field = "toggle_l2_devices_traffic_rrd_creation",
    default = "0",
    pref = "l2_device_rrd_creation",
    to_switch = {"row_l2_devices_ndpi_timeseries_creation", "rrd_files_retention"},
  })

  local l7_rrd_labels = {i18n("prefs.none"),
			 i18n("prefs.per_category")}
  local l7_rrd_values = {"none",
			 "per_category"}

  local showElement = ntop.getPref("ntopng.prefs.l2_device_rrd_creation") == "1"

  retVal = multipleTableButtonPrefs(subpage_active.entries["toggle_ndpi_timeseries_creation"].title,
				    subpage_active.entries["toggle_ndpi_timeseries_creation"].description,
				    l7_rrd_labels, l7_rrd_values,
				    "none",
				    "primary",
				    "l2_devices_ndpi_timeseries_creation",
				    "ntopng.prefs.l2_device_ndpi_timeseries_creation", nil,
				    elementToSwitch, showElementArray, javascriptAfterSwitch, showElement)

  prefsInputFieldPrefs(subpage_active.entries["rrd_files_retention"].title, subpage_active.entries["rrd_files_retention"].description,
		       "ntopng.prefs.", "rrd_files_retention", 30, "number",
		       showElement,
		       nil, nil, {min=1, max=365, --[[ TODO check min/max ]]})

  print('<tr><th colspan=2 class="info">'..i18n('prefs.other_timeseries')..'</th></tr>')

  local info = ntop.getInfo()

  if ntop.isPro() then
    prefsToggleButton({
      field = "toggle_flow_rrds",
      default = "0",
      pref = "flow_device_port_rrd_creation",
      disabled = not info["version.enterprise_edition"],
    })

    prefsToggleButton({
      field = "toggle_pools_rrds",
      default = "0",
      pref = "host_pools_rrd_creation",
    })
  end

  prefsToggleButton({
    field = "toggle_tcp_flags_rrds",
    default = "0",
    pref = "tcp_flags_rrd_creation",
  })

  prefsToggleButton({
    field = "toggle_tcp_retr_ooo_lost_rrds",
    default = "0",
    pref = "tcp_retr_ooo_lost_rrd_creation",
  })

  prefsToggleButton({
    field = "toggle_vlan_rrds",
    default = "0",
    pref = "vlan_rrd_creation",
  })

  prefsToggleButton({
    field = "toggle_asn_rrds",
    default = "0",
    pref = "asn_rrd_creation",
  })

  print('</table>')

  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.databases")..'</th></tr>')

  mysql_retention = 7
  prefsInputFieldPrefs(subpage_active.entries["mysql_retention"].title, subpage_active.entries["mysql_retention"].description .. "-F mysql;&lt;host|socket&gt;;&lt;dbname&gt;;&lt;table name&gt;;&lt;user&gt;;&lt;pw&gt;.",
    "ntopng.prefs.", "mysql_retention", mysql_retention, "number", not subpage_active.entries["mysql_retention"].hidden, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  
  --default value
  minute_top_talkers_retention = 365
  prefsInputFieldPrefs(subpage_active.entries["minute_top_talkers_retention"].title, subpage_active.entries["minute_top_talkers_retention"].description,
      "ntopng.prefs.", "minute_top_talkers_retention", minute_top_talkers_retention, "number", nil, nil, nil, {min=1, max=365*10, --[[ TODO check min/max ]]})
  print('</table>')

  print('<table class="table">')
if show_advanced_prefs and false --[[ hide these settings for now ]] then
  print('<tr><th colspan=2 class="info">Network Interface Timeseries</th></tr>')
  prefsInputFieldPrefs("Days for raw stats", "Number of days for which raw stats are kept. Default: 1.", "ntopng.prefs.", "intf_rrd_raw_days", prefs.intf_rrd_raw_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Days for 1 min resolution stats", "Number of days for which stats are kept in 1 min resolution. Default: 30.", "ntopng.prefs.", "intf_rrd_1min_days", prefs.intf_rrd_1min_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Days for 1 hour resolution stats", "Number of days for which stats are kept in 1 hour resolution. Default: 100.", "ntopng.prefs.", "intf_rrd_1h_days", prefs.intf_rrd_1h_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Days for 1 day resolution stats", "Number of days for which stats are kept in 1 day resolution. Default: 365.", "ntopng.prefs.", "intf_rrd_1d_days", prefs.intf_rrd_1d_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})

  print('<tr><th colspan=2 class="info">Protocol/Networks Timeseries</th></tr>')
  prefsInputFieldPrefs("Days for raw stats", "Number of days for which raw stats are kept. Default: 1.", "ntopng.prefs.", "other_rrd_raw_days", prefs.other_rrd_raw_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  --prefsInputFieldPrefs("Days for 1 min resolution stats", "Number of days for which stats are kept in 1 min resolution. Default: 30.", "ntopng.prefs.", "other_rrd_1min_days", prefs.other_rrd_1min_days)
  prefsInputFieldPrefs("Days for 1 hour resolution stats", "Number of days for which stats are kept in 1 hour resolution. Default: 100.", "ntopng.prefs.", "other_rrd_1h_days", prefs.other_rrd_1h_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Days for 1 day resolution stats", "Number of days for which stats are kept in 1 day resolution. Default: 365.", "ntopng.prefs.", "other_rrd_1d_days", prefs.other_rrd_1d_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
end
  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')
  print('</table>')

  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printLogging()
  if prefs.has_cmdl_trace_lvl then return end
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.logging")..'</th></tr>')

  loggingSelector(subpage_active.entries["toggle_logging_level"].title, subpage_active.entries["toggle_logging_level"].description,
        "toggle_logging_level", "ntopng.prefs.logging_level")

  prefsToggleButton({
    field = "toggle_access_log",
    default = "0",
    pref = "enable_access_log",
  })

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')

  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>
  </table>]]
end

function printSnmp()
  if not ntop.isPro() then return end

  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">SNMP</th></tr>')

  prefsToggleButton({
    field = "toggle_snmp_rrds",
    default = "0",
    pref = "snmp_devices_rrd_creation",
    disabled = not info["version.enterprise_edition"],
  })

  prefsInputFieldPrefs(subpage_active.entries["default_snmp_community"].title, subpage_active.entries["default_snmp_community"].description,
		       "ntopng.prefs.",
		       "default_snmp_community",
		       "public", false, nil, nil, nil,  {attributes={spellcheck="false", maxlength=64}})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')

  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>
  </table>]]
end

function printFlowDBDump()
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.tiny_flows")..'</th></tr>')

  prefsToggleButton({
    field = "toggle_flow_db_dump_export",
    default = "1",
    pref = "flow_db_dump_export_enabled",
  })

  prefsInputFieldPrefs(subpage_active.entries["max_num_packets_per_tiny_flow"].title, subpage_active.entries["max_num_packets_per_tiny_flow"].description,
        "ntopng.prefs.", "max_num_packets_per_tiny_flow", prefs.max_num_packets_per_tiny_flow, "number", true, false, nil, {min=1, max=2^32-1})

  prefsInputFieldPrefs(subpage_active.entries["max_num_bytes_per_tiny_flow"].title, subpage_active.entries["max_num_bytes_per_tiny_flow"].description,
        "ntopng.prefs.", "max_num_bytes_per_tiny_flow", prefs.max_num_bytes_per_tiny_flow, "number", true, false, nil, {min=1, max=2^32-1})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px">'..i18n("save")..'</button></th></tr>')

  print [[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>
  </table>]]
end

   print[[
       <table class="table table-bordered">
         <col width="20%">
         <col width="80%">
         <tr><td style="padding-right: 20px;">]]

   print(
      template.gen("typeahead_input.html", {
        typeahead={
          base_id     = "prefs_search",
          action      = "/lua/admin/prefs.lua",
          json_key    = "tab",
          query_field = "tab",
          query_url   = ntop.getHttpPrefix() .. "/lua/find_prefs.lua",
          query_title = i18n("prefs.search_preferences"),
          style       = "width:20em; margin:auto; margin-top: 0.4em; margin-bottom: 1.5em;",
        }
      })
    )

   print[[
           <div class="list-group">]]

printMenuSubpages(tab)

print[[
           </div>
           <br>
           <div align="center">

            <div id="prefs_toggle" class="btn-group">
              <form method="post">
<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
<input type=hidden name="show_advanced_prefs" value="]]if show_advanced_prefs then print("false") else print("true") end print[["/>


<br>
<div class="btn-group btn-toggle">
]]

local cls_on      = "btn btn-sm"
local onclick_on  = ""
local cls_off     = cls_on
local onclick_off = onclick_on
if show_advanced_prefs then
   cls_on  = cls_on..' btn-primary active'
   cls_off = cls_off..' btn-default'
   onclick_off = "this.form.submit();"
else
   cls_on = cls_on..' btn-default'
   cls_off = cls_off..' btn-primary active'
   onclick_on = "this.form.submit();"
end
print('<button type="button" class="'..cls_on..'" onclick="'..onclick_on..'">'..i18n("prefs.expert_view")..'</button>')
print('<button type="button" class="'..cls_off..'" onclick="'..onclick_off..'">'..i18n("prefs.simple_view")..'</button>')

print[[
</div>
              </form>

            </div>

           </div>

        </td><td colspan=2 style="padding-left: 14px;border-left-style: groove; border-width:1px; border-color: #e0e0e0;">]]

if(tab == "report") then
   printReportVisualization()
end

if(tab == "in_memory") then
   printInMemory()
end

if(tab == "on_disk_ts") then
   printStatsTimeseries()
end

if(tab == "alerts") then
   printAlerts()
end

if(tab == "ext_alerts") then
   printExternalAlertsReport()
end

if(tab == "protocols") then
   printProtocolPrefs()
end

if(tab == "nbox") then
  if(ntop.isPro()) then
     printNbox()
  end
end

if(tab == "discovery") then
   printNetworkDiscovery()
end

if(tab == "bridging") then
  if(info["version.enterprise_edition"]) then
     printBridgingPrefs()
  end
end

if(tab == "misc") then
   printMisc()
end
if(tab == "auth") then
   printAuthentication()
end
if(tab == "ifaces") then
   printInterfaces()
end
if(tab == "logging") then
   printLogging()
end
if(tab == "snmp") then
   printSnmp()
end
if(tab == "flow_db_dump") then
   printFlowDBDump()
end

print[[
        </td></tr>
      </table>
]]

   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

   print([[<script>
aysHandleForm("form");

/* Use the validator plugin to override default chrome bubble, which is displayed out of window */
$("form[id!='search-host-form']").validator({disable:true});
</script>]])

if(_SERVER["REQUEST_METHOD"] == "POST") then
   -- Something has changed
  ntop.reloadPreferences()
end

if(_POST["toggle_malware_probing"] ~= nil) then
  loadHostBlackList(true --[[ force the reload of the list ]])
end

end --[[ haveAdminPrivileges ]]
