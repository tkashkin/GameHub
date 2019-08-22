namespace GameHub.Data.Sources.Itch { 
    
    public delegate void JsonMemberSetter(Json.Builder json_builder);

    /**
     * Helper to build a JSON object used in API calls
     * 
     * Takes a closure as parameter, which is passed a Json.Builder containing a currently
     * open JSON object. Members can be added to the object with Json.Builder methods
     * 
     * Returns a Json.Node as it is easier to serialize or combine it than Json.Object
     */
    public Json.Node build_json_object(JsonMemberSetter member_setter = null)
    {
        Json.Builder json_builder = new Json.Builder();

        json_builder.begin_object();
        if(member_setter != null) {
            member_setter(json_builder);
        }
        json_builder.end_object();

        return json_builder.get_root();
    }

    /**
     * Returns the profile ID from a Login API call
     */
    public int get_profile_id(Json.Object login_result)
    {
        return (int)login_result.get_object_member("profile").get_int_member("id");
    }

}