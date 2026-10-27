using System;
class LocationFallbackTest {
    static int Main() {
        double lat,lon;
        string[] invalid={"{}","null","not json","{\"success\":false}","{\"error\":true}","{\"country_code\":\"US\",\"latitude\":40,\"longitude\":-74}","{\"country_code\":\"CN\",\"latitude\":91,\"longitude\":116}","{\"country_code\":\"CN\",\"latitude\":\"NaN\",\"longitude\":116}","{\"country_code\":\"CN\",\"latitude\":39}"};
        foreach(string json in invalid) if(TrayHost.ParseIpLocation(json,out lat,out lon)) throw new Exception("Invalid provider response accepted");
        foreach(string country in new string[]{"CN","TW","HK","MO"}) {
            if(!TrayHost.ParseIpLocation("{\"success\":true,\"country_code\":\""+country+"\",\"latitude\":39.9,\"longitude\":116.4}",out lat,out lon) || Math.Abs(lat-39.9)>.00001 || Math.Abs(lon-116.4)>.00001) throw new Exception("Valid provider response rejected");
        }
        if(!TrayHost.ParseIpLocation("{\"country_code\":\"CN\",\"latitude\":39.9,\"longitude\":116.4}",out lat,out lon)) throw new Exception("Secondary provider response rejected");
        Console.WriteLine("NATIVE LOCATION RESULT: 14 passed, 0 failed");
        return 0;
    }
}
