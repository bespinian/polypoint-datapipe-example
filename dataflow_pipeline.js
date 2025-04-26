function process(inJson) {
  val = inJson.split(",");

  const obj = { "name": val[0], "age": parseInt(val[1]) };
  return JSON.stringify(obj);
}